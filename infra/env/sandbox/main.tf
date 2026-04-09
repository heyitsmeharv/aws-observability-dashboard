module "demo" {
  source = "../../../examples/react-node-demo/infra"

  # Hardcoded to "obs-demo" — ALB names have a 32-char limit, the root
  # project name ("aws-observability-dashboard") would exceed it.
  project     = "obs-demo"
  environment = var.environment
  aws_region  = var.aws_region

  instance_type    = var.demo_instance_type
  desired_capacity = var.demo_desired_capacity
  max_capacity     = var.demo_max_capacity

  enable_canaries  = var.demo_enable_canaries
  enable_tracing   = var.demo_enable_tracing
  create_sns_topic = var.demo_create_sns_topic
}
