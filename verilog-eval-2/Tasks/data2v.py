import json
import os


def write_to_txt(file_name, content, mode='a', write_signal=True):
    if write_signal:
        with open(file_name, mode, encoding='utf-8') as f:
            f.write(f"{content}")
    else: return 


# task = "code-complete-iccad2023.jsonl"
task = "spec-to-rtl.jsonl"

def d2v(file):
    path = "./" + file.split(".")[0]
    if not os.path.exists(path):
        os.mkdir(path)
    
    with open(file, "r") as f:
        for line in f:
            json_obj = json.loads(line)
            task_id = json_obj['task_id']
            interface = json_obj['interface']
            description = json_obj['prompt']
            code = json_obj['ref_module']
            testbench = json_obj['testbench']
            whole = f"""
// {'-'*25}  Description {'-'*25}
{description}

// {'-'*25}  Referred Module {'-'*25}
{code}

// {'-'*25}  Testbench {'-'*25}
{testbench}
"""
            write_to_txt(f"{path}/{task_id}.v", whole,'w')

d2v(task)
# d2v(Machine)