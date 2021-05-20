output "bastion_passthrough" {
  value       = module.bastion.bastion_passthrough
  description = "Command to set up ssh tunnel to access the grafana dashboard. Export path to private key as SSH_KEY in environment."
}
output "bastion_public_ip" {
  value       = module.bastion.bastion_public_ip
  description = "the public ip address of the bastion to curl from the source"
}

output "bastion_private_ip" {
  value       = module.bastion.bastion_private_ip
  description = "the public ip address of the bastion to curl from the source"
}

output "source_ip" {
  value       = module.workloads.source_ip
  description = "The private ip address of the source"
}

output "destination_ip" {
  value       = module.workloads.destination_ip
  description = "The destination ip address of the source"
}

output "socks_proxy_command" {
  value       = "ssh -i ${var.ssh_private_key} -D 9876 ec2-user@${module.bastion.bastion_public_ip} -N"
  description = "Enable socks5 tunneling via bastion to enable local kubectl to communicate with private cluster"
}

output "sample_kubectl_cmd" {
  value       = "HTTPS_PROXY=socks5://localhost:9876 kubectl get pods"
  description = "Example syntax on how to call kubectl so that requests are forwarded via socks proxy.\nNOTE: Forwarding of `kubectl exec` is not supported"
}

output "source_ssh_command" {
  value       = "ssh -i ${var.ssh_private_key} -o ProxyCommand='ssh -i ${var.ssh_private_key} ec2-user@${module.bastion.bastion_public_ip} nc %h %p' ec2-user@${module.workloads.source_ip}"
  description = "Command to ssh to the Source machine. Export path to private key as SSH_KEY in environment."
}

output "destination_ssh_command" {
  value       = "ssh -i ${var.ssh_private_key} -o ProxyCommand='ssh -i ${var.ssh_private_key} ec2-user@${module.bastion.bastion_public_ip} nc %h %p' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@${module.workloads.destination_ip}"
  description = "Command to ssh to the destination machine. Export path to private key as SSH_KEY in environment."
}