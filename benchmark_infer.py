
import json
import re
from vllm import LLM, SamplingParams
from functools import partial
import os
import argparse
import subprocess
import shutil
import math
import warnings
from transformers import AutoModelForCausalLM, AutoTokenizer
from execution import check_correctness
from collections import defaultdict
import sys

def calculate_task_pass_at_k(input_file_path, k=5):
    """
    计算JSONL文件中每个任务的pass@k
    
    参数:
        input_file_path: JSONL文件路径
        k: 抽取次数（默认k=5，常用值：1、5、10、20）
    
    返回:
        task_pass_dict: 字典 {task_id: pass@k值}
        average_pass: 所有任务的平均pass@k
    """
    # 按task_id分组，收集每个任务的20次通过结果
    task_results = defaultdict(list)
    
    # 读取JSONL文件并解析
    with open(input_file_path, 'r', encoding='utf-8') as f:
        for line_idx, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue  # 跳过空行
            
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                warnings.warn(f"第{line_idx}行JSON格式错误，已跳过")
                continue
            
            # 提取必要字段
            task_id = data.get('task_id')
            score = data.get('score')
            
            # 校验字段完整性
            if task_id is None:
                warnings.warn(f"第{line_idx}行缺少'task_id'字段，已跳过")
                continue
            if score is None:
                warnings.warn(f"第{line_idx}行缺少'score'字段，已跳过")
                continue
            
            # 判断是否通过（1.0为通过，其他为失败）
            is_pass = float(score) == 1.0
            task_results[task_id].append(is_pass)
    
    # 计算每个任务的pass@k
    task_pass_dict = {}
    expected_trials = 20  # 每个任务预期20次结果
    
    for task_id, results in task_results.items():
        m = len(results)  # 该任务实际的尝试次数
        s = sum(results)  # 该任务的通过次数
        
        # 校验尝试次数是否为20次（给出警告）
        if m != expected_trials:
            warnings.warn(
                f"任务{task_id}实际尝试次数为{m}（预期20次），"
                "计算结果可能不准确，请检查数据"
            )
        
        # 核心逻辑计算pass@k
        if s == 0:
            # 无通过记录，pass@k=0
            pass_k = 0.0
        elif k >= m:
            # 抽取次数≥总尝试数，必然包含通过记录，pass@k=1
            pass_k = 1.0
        else:
            # 计算组合数：从失败次数中选k次的概率（全失败）
            failed_count = m - s
            comb_failed = math.comb(failed_count, k)  # 失败组合数
            comb_total = math.comb(m, k)              # 总组合数
            pass_k = 1.0 - (comb_failed / comb_total)  # 至少一次通过的概率
        
        task_pass_dict[task_id] = round(pass_k, 4)  # 保留4位小数
    
    # 计算所有任务的平均pass@k
    total_tasks = len(task_pass_dict)
    average_pass = round(
        sum(task_pass_dict.values()) / total_tasks, 4
    ) if total_tasks > 0 else 0.0
    
    return task_pass_dict, average_pass

def write_to_txt(file_name, content, mode='a', write_signal=True):
    if write_signal:
        with open(file_name, mode, encoding='utf-8') as f:
            f.write(f"{content}")
    else: return 

def get_code(file_content):
    file_content = file_content.split("## Code Implementation")[-1]
    verilog_blocks = re.findall(r"```verilog\s*(.*?)```", file_content, re.DOTALL)
    if verilog_blocks:
        # code = "\n"
        # for vb in verilog_blocks:
        #     if vb in code:
        #         continue
        #     code += f"{vb}\n"
        code = verilog_blocks[-1]
    else:
        code = file_content
    return code

def get_code_wo_notes(file_content):
    # 提取 "## Code Implementation" 后的部分
    file_content = file_content.split("## Code Implementation")[-1]

    # 提取 Verilog 代码块（```verilog ... ```) 或原始内容
    verilog_blocks = re.findall(r"```verilog\s*(.*?)```", file_content, re.DOTALL)
    # code = "\n".join(verilog_blocks) if verilog_blocks else file_content
    if verilog_blocks:
        code = verilog_blocks[-1]
    else:
        code = file_content

    # 去除 /* 多行注释 */
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)

    # 去除 // 单行注释（不跨行）
    code = re.sub(r"//.*", "", code)

    # 可选：去除空行和多余空格
    code = "\n".join(line.rstrip() for line in code.splitlines() if line.strip())

    return code

def extract_verilog(content):
    verilog_code = get_code(content)
    lines = verilog_code.splitlines()
    header_lines = []
    remaining_lines = []
    in_module = False
    header_complete = False
    
    for line in lines:
        if not header_complete:
            header_lines.append(line)
            if not in_module and line.strip().startswith('module'):
                in_module = True
            if in_module and line.strip().endswith(');'):
                header_complete = True
        else:
            remaining_lines.append(line)
    
    header = '\n'.join(header_lines)
    remaining = '\n'.join(remaining_lines)
    return header, remaining

def parse_out(text, mode="high"):
    pattern = r"\{'pass@1': ([\d.]+), 'pass@5': ([\d.]+), 'pass@10': ([\d.]+)\}"
    if mode=='low':
        pattern = r"\{'pass@1': ([\d.]+)\}"
    if not isinstance(text, str):
        text = str(text)
    match = re.search(pattern, text)

    if match:
        if mode == 'low':
            pass_at_1 = float(match.group(1))
            return {'pass@1': pass_at_1}
        pass_at_1 = float(match.group(1))
        pass_at_5 = float(match.group(2))
        pass_at_10 = float(match.group(3))
        return {'pass@1': pass_at_1, 'pass@5': pass_at_5, 'pass@10': pass_at_10}
    else:
        print("未找到 pass 数据。")
        return text
    

class VerilogGenBenchmark:
    def __init__(self, model_path, use_template=True):
        self.use_template = use_template
        self.model_path = model_path
        self.llm = LLM(model=model_path) #, tensor_parallel_size=8)

    
    def sampling_parameters(self, temperature, top_p=None):
        if top_p:
            sampling_params = SamplingParams(
                n=1,
                temperature=temperature,
                top_p=top_p,
                max_tokens=4096
            )
        else:
            sampling_params = SamplingParams(temperature=temperature, max_tokens=4096)
        return sampling_params

    
    def get_response(self, Prompts, sampling_params, response_batch=20):
        all_conversations = []
        for prompt in Prompts:
            if self.use_template:
                sys_prompt = "You are a helpful assistant."
                full_prompt = [
                    {
                        "role": "system",
                        "content": sys_prompt
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            else:
                full_prompt = prompt
            for i in range(response_batch):
                all_conversations.append(full_prompt)
        
        print("="*20, f" Example of Intructions ", "="*20)
        print(len(all_conversations), all_conversations[0])
        print("="*50)
        if self.use_template:
            original_list = self.llm.chat(messages=all_conversations,
                        sampling_params=sampling_params,
                        use_tqdm=True)
        else:
            original_list = self.llm.generate(all_conversations,
                        sampling_params=sampling_params,
                        use_tqdm=True)
        Result_dict = []
        for idx, output in enumerate(original_list):
            text = output.outputs[0].text
            verilog_code = get_code_wo_notes(text)
    
            header, body = extract_verilog(verilog_code)
            code_results = {
                'full_code': verilog_code,
                'code_header': header,
                'code_body': body if body else verilog_code,
                'direct_output':  text
            }

            # self.Whole_Record.append(code_results)
            Result_dict.append(code_results)
        return Result_dict
    

    def run_VerilogEval_v1(self, temperature, top_p=None, response_batch=20, GType=None, fold_idx=""):
        save_path = "./VerilogEval-v1"
        os.makedirs(save_path, exist_ok=True)
        dir_path = f"{save_path}/{self.model_name}-{fold_idx}"
        # # 如果目录已存在，则删除
        # if os.path.exists(dir_path):
        #     shutil.rmtree(dir_path)
        # # 创建新目录
        os.makedirs(dir_path, exist_ok=True)
        sampling_params = self.sampling_parameters(temperature, top_p)
        if temperature == 0.0:
            response_batch = 1
        if GType == None:
            GType = ["Machine", "Human"]
        for gtype in GType: 
            infile = f"./verilog-eval-v1/CompleteData/VerilogEval_{gtype}.jsonl"
            outfile = f"{save_path}/{self.model_name}-{fold_idx}/VerilogEval_{gtype}_temp{temperature}.jsonl"
            if os.path.exists(outfile):
                os.remove(outfile)
            score_file = f"{save_path}/VerilogEval_{gtype}_temp{temperature}_score.jsonl"
            with open(infile, "r") as f:
                Prompts = []
                All_Data = []
                for line in f:
                    data = json.loads(line)
                    task_id = data["task_id"]
                    official_des = data['description']
                    module_head = data['prompt']
                    canonical_solution = data['canonical_solution']
                    sub_data = {
                        "task_id": task_id,
                        "description": official_des,
                        "prompt": module_head,
                    }
                    All_Data.append(sub_data)
                    Prompts.append(official_des.strip()+"\n"+module_head.strip())

            with open(outfile, "a") as sf:
                Results = self.get_response(Prompts, sampling_params, response_batch)
                for idx in range(len(All_Data)):
                    for cid in range(idx * response_batch, (idx+1) * response_batch):
                        All_Data[idx]["completion"] = Results[cid]['code_body']
                        All_Data[idx]["full_code"] = Results[cid]['full_code']
                        All_Data[idx]["code_header"] = Results[cid]['code_header']
                        All_Data[idx]["redes"] = Results[cid]['direct_output']
                        All_Data[idx]["maintain"] = All_Data[idx]["description"] in All_Data[idx]["redes"]
                        sf.write(json.dumps(All_Data[idx])+'\n')
            
            # evaluate_functional_correctness /workspace/S/huanglei/VerilogGen-Benchmark/VerilogEval-v1/DAPOMerge106-CD-420/VerilogEval_Human_temp0.2.jsonl --problem_file /workspace/S/huanglei/verilog-eval/data/VerilogEval_Human.jsonl
            command = f"evaluate_functional_correctness {outfile} --problem_file ./verilog-eval-v1/data/VerilogEval_{gtype}.jsonl"
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            pass_rate = parse_out(result)
            pass_rate['model'] = self.model_name
            with open(score_file, 'a') as f:
                json_line = json.dumps(pass_rate) + '\n'
                f.write(json_line)
        

    def run_VerilogEval_v2(self, task = "code-complete-iccad2023", mode='high', fold_idx=""):
        # Only Pass@1 with number of samples n=1 (temperature=0, top_p=0.01) and n=20 (temperature=0.85, top_p=0.95)
        if mode == "high":
            temperature=0.85
            top_p=0.95
            response_batch = 20
        elif mode == "low":
            temperature=0.0
            top_p=0.01
            response_batch = 1
        else:
            None

        sampling_params = self.sampling_parameters(temperature, top_p)

        os.makedirs("./VerilogEval-v2", exist_ok=True)
        save_path = f"./VerilogEval-v2/{task}"
        os.makedirs(save_path, exist_ok=True)
        dir_path = f"{save_path}/{self.model_name}-{fold_idx}"
        # # 如果目录已存在，则删除
        # if os.path.exists(dir_path):
        #     shutil.rmtree(dir_path)
        # # 创建新目录
        os.makedirs(dir_path, exist_ok=True)

        infile = f"./verilog-eval-2/Tasks/{task}.jsonl"

        outfile = f"{save_path}/{self.model_name}-{fold_idx}/VerilogEval_{mode}.jsonl"
        if os.path.exists(outfile):
            os.remove(outfile)

        score_file = f"{save_path}/VerilogEval_{mode}_score.jsonl"
        with open(infile, 'r') as file:
            All_Data = []
            Prompts = []
            for line in file:
                data = json.loads(line)
                task_id = data["task_id"]
                interface = data['interface']
                description = data['prompt']
                ref_module = data['ref_module']
                sub_data = {
                    "task_id": task_id,
                    "description": description,
                    "interface": interface
                }
                All_Data.append(sub_data)
                Prompts.append(data['prompt'])
                # if self.use_template:
                #     Prompts.append(data['prompt'])
                # else:

        
        with open(outfile, "a") as sf:
            Results = self.get_response(Prompts, sampling_params, response_batch)
            for idx in range(len(All_Data)):
                for cid in range(idx * response_batch, (idx+1) * response_batch):
                    if task=='spec-to-rtl':
                        All_Data[idx]["interface"] = Results[cid]['code_header']
                        All_Data[idx]["completion"] = Results[cid]['full_code']
                    else:
                        All_Data[idx]["completion"] = Results[cid]['code_body']
                    All_Data[idx]["full_code"] = Results[cid]['full_code']
                    All_Data[idx]["code_header"] = Results[cid]['code_header']
                    All_Data[idx]["redes"] = Results[cid]['direct_output']
                    All_Data[idx]["maintain"] = All_Data[idx]["description"] in All_Data[idx]["redes"]
                    sf.write(json.dumps(All_Data[idx])+'\n')
        # /workspace/S/huanglei/VerilogGen-Benchmark/VerilogEval-v2/spec-to-rtl/FSM_BlockCoT_SFT-1000-/VerilogEval_low.jsonl
        command = f"python ./verilog-eval-2/evaluation/evaluate_functional_correctness.py {outfile} --problem_file ./verilog-eval-2/Tasks/{task}.jsonl"
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        pass_rate = parse_out(result, mode)
        if isinstance(pass_rate, dict):
            pass_rate['model'] = self.model_name
        with open(score_file, 'a') as f:
            json_line = json.dumps(pass_rate) + '\n'
            f.write(json_line)
    
    
    def run_VerilogEval_v2_with_temperature(self, task ="code-complete-iccad2023", temperature=0.0, top_p=None, response_batch=20):
        sampling_params = self.sampling_parameters(temperature, top_p)

        os.makedirs("./VerilogEval-v2", exist_ok=True)
        save_path = f"./VerilogEval-v2/{task}"
        os.makedirs(save_path, exist_ok=True)
        os.makedirs(f"{save_path}/{self.model_name}", exist_ok=True)

        infile = f"./verilog-eval-2/Tasks/{task}.jsonl"

        outfile = f"{save_path}/{self.model_name}/VerilogEval_{temperature}.jsonl"
        if os.path.exists(outfile):
                os.remove(outfile)
        score_file = f"{save_path}/VerilogEval_{temperature}_score.jsonl"
        with open(infile, 'r') as file:
            All_Data = []
            Prompts = []
            for line in file:
                data = json.loads(line)
                task_id = data["task_id"]
                interface = data['interface']
                description = data['prompt']
                ref_module = data['ref_module']
                sub_data = {
                    "task_id": task_id,
                    "description": description,
                    "interface": interface
                }
                All_Data.append(sub_data)
                Prompts.append(data['prompt'])
        
        with open(outfile, "a") as sf:
            Results = self.get_response(Prompts, sampling_params, response_batch)
            for idx in range(len(All_Data)):
                for cid in range(idx * response_batch, (idx+1) * response_batch):
                    if task=='spec-to-rtl':
                        All_Data[idx]["interface"] = Results[cid]['code_header']
                        All_Data[idx]["completion"] = Results[cid]['full_code']
                    else:
                        All_Data[idx]["completion"] = Results[cid]['code_body']
                    All_Data[idx]["full_code"] = Results[cid]['full_code']
                    All_Data[idx]["code_header"] = Results[cid]['code_header']
                    All_Data[idx]["redes"] = Results[cid]['direct_output']
                    All_Data[idx]["maintain"] = All_Data[idx]["description"] in All_Data[idx]["redes"]
                    sf.write(json.dumps(All_Data[idx])+'\n')
    
        command = f"python ./verilog-eval-2/evaluation/evaluate_functional_correctness.py {outfile} --problem_file .i/verilog-eval-2/Tasks/{task}.jsonl"
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
        pass_rate = parse_out(result)
        if isinstance(pass_rate, dict):
            pass_rate['model'] = self.model_name
        with open(score_file, 'a') as f:
            json_line = json.dumps(pass_rate) + '\n'
            f.write(json_line)
        

    def run_RTLLM_v1(self, temperature, response_batch=20, fold_idx=""):
        infile = "./RTLLM/complete_data.jsonl"
        bigsave_path = f"./RTLLM_Benchmark"
        os.makedirs(bigsave_path, exist_ok=True)
        os.makedirs(f"{bigsave_path}/{self.model_name}{fold_idx}", exist_ok=True)
        os.makedirs(f"{bigsave_path}/{self.model_name}{fold_idx}/temperature_{temperature}", exist_ok=True)
        save_path = f"{bigsave_path}/{self.model_name}{fold_idx}/temperature_{temperature}"
        sampling_params = self.sampling_parameters(temperature)
        if temperature == 0.0:
            response_batch = 1
        for res_bc in range(response_batch):
            os.makedirs(f"{save_path}/test_{res_bc}", exist_ok=True)
        
        with open(infile, 'r') as file:
            All_Data = []
            Prompts = []
            for line in file:
                data = json.loads(line)
                task_id = data["task_id"]
                description = data['description']
                verified = data['verified']

                sub_data = {
                    "task_id": task_id,
                    "description": description,
                    "verified": verified
                }
                All_Data.append(sub_data)
                ## Because the CodeV dataset was constructed by collecting publicly available Verilog code from the internet and summarizing it hierarchically using ChatGPT, many of the hierarchical design tasks in the dataset lack the corresponding lower-level modules. To address this issue, we inserted an additional instruction into the few training samples that do contain complete hierarchical designs, reminding the model that all submodules must be implemented when handling hierarchical tasks. Since RTLLM contains many such hierarchical design examples, we included the same instruction in our prompt to ensure consistent model behavior.
                description = description.replace("\n\nGive me the complete code.", "If there are sub modules in the code, you need to implement them to form a complete executable Verilog code.\n\nGive me the complete code.") 
                # if self.use_template:
                Prompts.append(description.strip())
                # else:
                #     Prompts.append(data['description'].strip() + "\n" + data['interface'])
        
        Results = self.get_response(Prompts, sampling_params, response_batch)
        for idx in range(len(All_Data)):
            for cid in range(idx * response_batch, (idx+1) * response_batch):
                full_code = Results[cid]['full_code']
                write_to_txt(f"{save_path}/test_{cid % response_batch}/{All_Data[idx]['task_id']}.v", full_code, 'w')

#### 只需要指定模型就行
parser = argparse.ArgumentParser(description='input gtype')
parser.add_argument('--model', help='model_path')
args = parser.parse_args()

VGB = VerilogGenBenchmark(model_path=args.model)

VGB.run_VerilogEval_v2(task = "code-complete-iccad2023",mode='high')
VGB.run_VerilogEval_v2(task = "code-complete-iccad2023",mode='low')
VGB.run_VerilogEval_v2(task = "spec-to-rtl",mode='high')
VGB.run_VerilogEval_v2(task = "spec-to-rtl",mode='low')
for t in [0.2, 0.5, 0.8]:
    VGB.run_RTLLM_v1(temperature=t)
    VGB.run_VerilogEval_v1(temperature=t, response_batch=20, GType=None)

        
        


