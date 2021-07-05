resource "digitalocean_app" "api_app" {
    spec {
        name = "poc-express-app"
        region = local.region

        service {
            name = "poc-express-app-service"
            build_command = "yarn run build"
            source_dir = "graphile/api"
            run_command = "yarn start"
            environment_slug = "node-js"

            github {
                branch = "do-poc"
                deploy_on_push = false
                repo = "jcgsville/project-expedius"
            }
        }
    }
}