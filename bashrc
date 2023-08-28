yq() {
  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
}

alias k='kubectl'

alias kg='kubectl get'
alias kgoy='kubectl get -o=yaml'
alias kgoj='kubectl get -o=json'
alias kgp='kubectl get pods'
alias kgpo='kubectl get pods -o wide'
alias kgpsys='kubectl get pods -n kube-system'
alias kgposys='kubectl get pods -n kube-system -o wide'
alias kgn='kubectl get nodes'
alias kgno='kubectl get nodes -o wide'
alias kgd='kubectl get deployment'
alias kgs='kubectl get statefulset'
alias kgsvc='kubectl get service'


alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kdpsys='kubectl describe pod -n kube-system'
alias kdn='kubectl describe node'
alias kdd='kubectl describe deployment'
alias kds='kubectl describe statefulset'
alias kdsvc='kubectl describe service'

alias ke='kubectl exec -ti'

alias kl='kubectl logs'
alias kl='kubectl logs -f'

alias kaf='kubectl apply -f'

alias krm='kubectl delete'
alias krmp='kubectl delete pod'
alias krmpsys='kubectl delete pod -n kube-system'
alias krmn='kubectl delete node'
alias krmd='kubectl delete deployment'
alias krms='kubectl delete statefulset'
alias krmsvc='kubectl delete service'
alias ks='kubectl sniff -p -n default -o -'

complete -o default -F __start_kubectl k
yq() {
  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
}

complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc
export AWS_DEFAULT_REGION="us-west-2"
alias wa='watch '

alias ..='cd ..'
alias ...='cd ../..'

## Use a long listing format ##
alias ll='ls -lart'
## Show hidden files ##
#alias l.='ls -d .* --color=auto'

## a quick way to get out of current directory ##
alias h='history'
# Do not wait interval 1 second, go fast #
alias fastping='ping -c 100 -s.2'
alias ports='netstat -tulanp'

# confirmation #
alias mv='mv -i'
alias cp='cp -i'
alias ln='ln -i'

alias update='sudo yum -y update'
alias root='sudo -i'

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
