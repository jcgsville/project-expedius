# resource "digitalocean_database_cluster" "eg_db_cluster" {
#   name       = "poc-postgres-cluster"
#   engine     = "pg"
#   version    = "13"
#   size       = "db-s-1vcpu-1gb"
#   region     = local.region
#   node_count = 1
# }

# resource "digitalocean_database_db" "eg_db" {
#     cluster_id = digitalocean_database_cluster.eg_db_cluster.id
#     name       = "eg"
# }