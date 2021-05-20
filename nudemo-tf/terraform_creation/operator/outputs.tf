output "elb_dns_name" {
  value       = data.local_file.elb_dns_name.content
  description = "the dns name of the elastic load balancer that the edge-proxy is in front of"
}