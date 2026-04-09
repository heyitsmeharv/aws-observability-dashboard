moved {
  from = module.observability.aws_sns_topic.alarms[0]
  to   = module.observability.module.observability.aws_sns_topic.alarms[0]
}

moved {
  from = module.observability.module.alarms
  to   = module.observability.module.observability.module.alarms
}

moved {
  from = module.observability.module.logs_insights
  to   = module.observability.module.observability.module.logs_insights
}

moved {
  from = module.observability.module.dashboards
  to   = module.observability.module.observability.module.dashboards
}

moved {
  from = module.observability.module.canaries[0]
  to   = module.observability.module.observability.module.canaries[0]
}
