# Auto-generated file. Do not edit manually.

resource "google_compute_subnetwork" "prd_subnet_01" {
  name                     = "prd-subnet-01"
  ip_cidr_range            = "10.0.1.0/24"
  region                   = "asia-northeast1"
  network                  = google_compute_network.vpc_prod[0].id
  project                  = module.vpc_host_prod[0].project_id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "dev_subnet_01" {
  name                     = "dev-subnet-01"
  ip_cidr_range            = "10.1.1.0/24"
  region                   = "asia-northeast1"
  network                  = google_compute_network.vpc_dev[0].id
  project                  = module.vpc_host_dev[0].project_id
  private_ip_google_access = true
}

output "shared_vpc_subnet_ids" {
  value = {
    "prd-subnet-01" = google_compute_subnetwork.prd_subnet_01.id
    "dev-subnet-01" = google_compute_subnetwork.dev_subnet_01.id
  }
}

