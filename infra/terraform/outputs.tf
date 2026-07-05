output "control_plane_public_ip" {
  value = module.compute.control_plane_public_ip
}

output "control_plane_private_ip" {
  value = module.compute.control_plane_private_ip
}

output "worker_public_ips" {
  value = module.compute.worker_public_ips
}

output "worker_private_ips" {
  value = module.compute.worker_private_ips
}
