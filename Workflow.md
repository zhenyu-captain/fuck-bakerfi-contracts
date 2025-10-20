# prompt
我们接着看看BKR-256在b-post-mitigation (f99edb1)和b-pre-mitigation (81485a9)的情况

# 安装环境
./down_versions.sh
./workspace/codeproject/1-setup.sh b-pre-mitigation 
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation 
./workspace/codeproject/3-verify-tools.sh b-pre-mitigation
./workspace/codeproject/4-verify-project.sh b-pre-mitigation

# 静态分析
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/1-extract-abi.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/2-extract-ast.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/3-extract-call-graph.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/4-extract-contract-summary.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/5-extract-data-dependency.sh b-pre-mitigation core
./workspace/analysis_security_tools/slither/5-extract-data-dependency.sh b-pre-mitigation interfaces
./workspace/analysis_security_tools/slither/6-extract-detectors.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/7-extract-function-summary.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/8-extract-slithir.sh b-pre-mitigation 

# 符号执行
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation
./workspace/analysis_security_tools/mythril/extract-symbolic-execution.sh b-pre-mitigation

# 目标
该是从b-pre-mitigation按照我们自己的方法重新发现找回BKR-195了
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation
./workspace/analysis_security_tools/echidna/extract-fuzzing.sh b-pre-mitigation core



