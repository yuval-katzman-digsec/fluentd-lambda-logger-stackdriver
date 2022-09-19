resource "local_file" "fluentd-config" {
  filename = "${path.module}/chart-fluentd-lambda-logger/fluentd-config.conf"
  content = <<-EOT
%{ for lambda in local.dig_region_lambdas ~}
<source>
  @type cloudwatch_logs
  tag ${lambda}
  log_group_name /aws/lambda/${lambda}
  use_todays_log_stream true
  use_aws_timestamp true
  fetch_interval 30
  throttling_retry_seconds 30
  region ${local.aws_region}
  state_file /fluentd-data/state_file-${lambda}
  <parse>
    @type json
  </parse>
  <web_identity_credentials>
  role_arn ${module.lambda_logs_sa.role.arn}
  role_session_name lambda-log-shipper-${lambda}
  web_identity_token_file /var/run/secrets/eks.amazonaws.com/serviceaccount/token
  </web_identity_credentials>
</source>
%{ endfor ~}

<filter **>
  @type record_transformer
  enable_ruby true
  <record>
    severity $${record["levelname"]}
    lambda_name $${tag}
  </record>
</filter>

<match fluent.**>
  @type null
</match>

<filter **>
  @type add_insert_ids
</filter>


<match **>
  @type google_cloud
  use_metadata_service false
  use_aws_availability_zone false
  project_id dig-it-333611
  zone "aws-lambda"
  detect_json true
  labels {
    "dig_env": "${var.environment}"
  }
</match>

EOT
}