output "bastion_public_ip" {
  value       = join("", aws_instance.Bastion[*].public_ip)
  description = "the public ip address of the bastion to curl from the source"
}

output "bastion_passthrough" {
  value       = "ssh -i ${var.ssh_private_key} ec2-user@${join("", aws_instance.Bastion[*].public_ip)} -L 8080:k.nuos.io:443"
  description = "Command to set up ssh tunnel to access the grafana dashboard. Export path to private key as SSH_KEY in environment."
}

output "bastion_private_ip" {
  value       = join("", aws_instance.Bastion[*].private_ip)
  description = "the private ip address of the bastion to curl from the source"
}

output "bastion_ready" {
  value       = data.local_file.bastion_ready.content
  description = "Flag indicates if bastion is ready"
}
