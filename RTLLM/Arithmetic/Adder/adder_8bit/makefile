.PHONY: vcs sim clean

TEST_DESIGN = adder_8bit

vcs:
		vcs -sverilog +v2k -timescale=1ns/1ns       \
		-debug_all         							\
		-l compile.log 								\
		/nfs_global/S/huanglei/RTLLM_Evaluation/Original-CodeV/test_0/adder_8bit.v testbench.v

sim:
		./simv -l run.log

clean:
		rm -rf *.log  csrc  simv*  *.key *.vpd  DVEfiles coverage *.vdb output.txt
