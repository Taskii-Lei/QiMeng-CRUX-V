import os
import time
import tqdm
from scipy.special import comb
import json
#import threading
from threading import Thread


def exec_shell(cmd_str, timeout=8):
    def run_shell_func(sh):
        os.system(sh)
    start_time = time.time()
    t = Thread(target=run_shell_func, args=(cmd_str,), daemon=False)
    t.start()
    while 1:
        now = time.time()
        if now - start_time >= timeout:
            if not t.is_alive():
                return 1
            else:
                return 0
        if not t.is_alive():
            return 1
        time.sleep(1)


def cal_atk(dic_list, n, k):
    #syntax 
    sum_list = []
    for design in dic_list.keys():
        c = dic_list[design]['syntax_success']
        sum_list.append(1 - comb(n - c, k) / comb(n, k))
    sum_list.append(0)
    syntax_passk = sum(sum_list) / len(sum_list)
    
    #func
    sum_list = []
    for design in dic_list.keys():
        c = dic_list[design]['func_success']
        sum_list.append(1 - comb(n - c, k) / comb(n, k))
    sum_list.append(0)
    func_passk = sum(sum_list) / len(sum_list)
    print(f'syntax pass@{k}: {syntax_passk},   func pass@{k}: {func_passk}')



progress_bar = tqdm.tqdm(total=290)
# design_name = ['adder_8bit', 'adder_16bit', 'adder_32bit', 'adder_pipe_64bit', 'adder_bcd', 'sub_64bit', 'multi_8bit', 'multi_16bit', 'multi_booth_8bit', 'multi_pipe_4bit', 
#                'multi_pipe_8bit', 'div_16bit', 'radix2_div', 'comparator_3bit', 'comparator_4bit', 'accu', 'fixed_point_adder', 'fixed_point_substractor', 'float_multi', 'asyn_fifo', 
#                'LIFObuffer', 'right_shifter', 'LFSR', 'barrel_shifter', 'fsm', 'sequence_detector', 'counter_12', 'JC_counter', 'ring_counter', 'up_down_counter', 
#                'signal_generator', 'square_wave', 'clkgenerator', 'instr_reg', 'ROM', 'RAM', 'alu', 'pe', 'freq_div', 'freq_divbyeven', 
#                'freq_divbyodd', 'freq_divfrac', 'calendar', 'traffic_light', 'width_8to16', 'synchronizer', 'edge_detect', 'pulse_detect', 'parallel2serial', 'serial2parallel']

design_name = ['accu', 'adder_8bit', 'adder_16bit', 'adder_32bit', 'adder_pipe_64bit', 'asyn_fifo', 'calendar', 'counter_12', 'edge_detect',
                'freq_div', 'fsm', 'JC_counter', 'multi_16bit', 'multi_booth_8bit', 'multi_pipe_4bit', 'multi_pipe_8bit', 'parallel2serial' , 'pe' , 'pulse_detect', 
                'radix2_div', 'RAM', 'right_shifter',  'serial2parallel', 'signal_generator','synchronizer', 'alu', 'div_16bit', 'traffic_light', 'width_8to16']
    
print(len(design_name))
with open("file_list.json", "r") as file:
    file_list = json.load(file)

full_design_name = {}
for fold in file_list.keys():
    for sf in file_list[fold].keys():
        tasks = file_list[fold][sf]
        for t in tasks:
            fpath = f"{fold}/{sf}/{t}"
            # all_design_name.append(fpath)
            if t in design_name:
                full_design_name[t] = fpath
                # design_name.append(fpath)
# print(f"all design name: {all_design_name}")
# print(f"design name: {design_name}")



path = "/nfs_global/S/huanglei/RTLLM_Evaluation/Original-CodeV"
result_dic = {key: {} for key in design_name}
for item in design_name:
    result_dic[item]['syntax_success'] = 0
    result_dic[item]['func_success'] = 0


def test_one_file(testfile, result_dic):
    for design in full_design_name.keys():
        if os.path.exists(f"{full_design_name[design]}/makefile"):
            print(f"test {design} in {testfile}")
            makefile_path = os.path.join(full_design_name[design], "makefile")
            with open(makefile_path, "r") as file:
                makefile_content = file.read()
                modified_makefile_content = makefile_content.replace("${TEST_DESIGN}", f"{path}/{testfile}/{design}")
                # modified_makefile_content = makefile_content.replace(f"{path}/{design}/{design}", "${TEST_DESIGN}")
            with open(makefile_path, "w") as file:
                file.write(modified_makefile_content)
            # Run 'make vcs' in the design folder
            os.chdir(full_design_name[design])
            os.system("make vcs")
            simv_generated = False
            if os.path.exists("simv"):
                simv_generated = True


            if simv_generated:
                result_dic[design]['syntax_success'] += 1
                # Run 'make sim' and check the result
                #os.system("make sim > output.txt")
                to_flag = exec_shell("make sim > output.txt")
                if to_flag == 1:
                    with open("output.txt", "r") as file:
                        output = file.read()
                        if "Pass" in output or "pass" in output:
                            result_dic[design]['func_success'] += 1
            
            with open("makefile", "w") as file:
                file.write(makefile_content)
            os.system("make clean")
            os.chdir("..")
            progress_bar.update(1)

    return result_dic

file_id = 0
n = 0
while os.path.exists(os.path.join(path, f"test_{file_id}")):
    # if file_id == 5:
    #     break
    print(f"test_{file_id}")
    result_dic = test_one_file(f"test_{file_id}", result_dic)
    n += 1
    file_id += 1
print(result_dic)
cal_atk(result_dic, n, 1)
total_syntax_success = 0
total_func_success = 0
for item in design_name:
    if result_dic[item]['syntax_success'] != 0:
        total_syntax_success += 1
    if result_dic[item]['func_success'] != 0:
        total_func_success += 1
print(f'total_syntax_success: {total_syntax_success}/{len(design_name)}')
print(f'total_func_success: {total_func_success}/{len(design_name)}')
# print(f"Syntax Success: {syntax_success}/{len(design_name)}")
# print(f"Functional Success: {func_success}/{len(design_name)}")
