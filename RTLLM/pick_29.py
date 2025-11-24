import json

design_name_ls_29 = ['accu', 'adder_8bit', 'adder_16bit', 'adder_32bit', 'adder_pipe_64bit', 'asyn_fifo', 'calendar', 'counter_12', 'edge_detect',
                'freq_div', 'fsm', 'JC_counter', 'multi_16bit', 'multi_booth_8bit', 'multi_pipe_4bit', 'multi_pipe_8bit', 'parallel2serial' , 'pe' , 'pulse_detect', 
                'radix2_div', 'RAM', 'right_shifter',  'serial2parallel', 'signal_generator','synchronizer', 'alu', 'div_16bit', 'traffic_light', 'width_8to16']


with open("./complete_data.jsonl", "r") as file, open("./complete_data_29.jsonl", "a") as sf:
    for line in file:
        entry = json.loads(line)
        if entry['task_id'] in design_name_ls_29:
            sf.write(line)


