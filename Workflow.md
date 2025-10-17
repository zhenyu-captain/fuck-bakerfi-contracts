# prompt
我们接着看看BKR-256在b-post-mitigation (f99edb1)和b-pre-mitigation (81485a9)的情况


# 安装环境
./down_versions.sh
./workspace/codeproject/1-setup.sh b-pre-mitigation 
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation 
./workspace/codeproject/3-verify-tools.sh b-pre-mitigation
./workspace/codeproject/4-verify-project.sh b-pre-mitigation

# 创建分析要素
source ./workspace/codeproject/2-activate-env.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/extract-abi.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/extract-ast.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/extract-call-graph.sh b-pre-mitigation
./workspace/analysis_security_tools/slither/extract-contract-summary.sh b-pre-mitigation


# 目标
该是从b-pre-mitigation按照我们自己的方法重新发现找回BKR-195了