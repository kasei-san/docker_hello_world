require 'aws-sdk'
require 'json'

BASE_NAME = 'docker_hello_world'
CLUSTER_NAME = 'hello_world'
EXECUTION_ROLE_ARN = ENV['EXECUTION_ROLE_ARN']
IMAGE_ARN = ENV['IMAGE_ARN']
SUBNET_1_ID = ENV['SUBNET_1_ID']
SUBNET_2_ID = ENV['SUBNET_2_ID']
SERVICE_SECURITY_GROUP_ID = ENV['SERVICE_SECURITY_GROUP_ID']

class TaskDefinition
  attr_reader :branch_name, :image_tag, :client, :register_task_definition_result

  def initialize(branch_name:, image_tag:, client:)
    @branch_name = branch_name
    @image_tag = image_tag
    @client = client
  end

  def register
    @register_task_definition_result = client.register_task_definition(
      task_definition
    ).to_h
  end

  def arn
    if @register_task_definition_result
      @arn ||= @register_task_definition_result[:task_definition][:task_definition_arn]
    else
      nil
    end
  end

  def task_definition
    {
      'container_definitions': [
        {
          'name': 'docker_hello_world_webserver',
          'image': "#{IMAGE_ARN}:#{image_tag}",
          'cpu': 0,
          'memory_reservation': 512,
          'port_mappings': [
            {
              'container_port': 80,
              'host_port': 80,
              'protocol': 'tcp'
            }
          ],
          'essential': true,
        }
      ],
      'family': "#{BASE_NAME}_#{branch_name}",
      'execution_role_arn': EXECUTION_ROLE_ARN,
      'network_mode': 'awsvpc',
      'requires_compatibilities': [
        'FARGATE'
      ],
      'cpu': '256',
      'memory': '512'
    }
  end
end

class Service
  attr_reader :branch_name, :client, :service_name, :task_definition_arn, :cluster

  def initialize(branch_name:, task_definition_arn:, client:)
    @branch_name = branch_name
    @task_definition_arn = task_definition_arn
    @client = client
    @service_name = "#{BASE_NAME}_#{branch_name}"
    @cluster = CLUSTER_NAME
  end

  def register
    if describe.nil?
      create
    else
      update
      restart_task
    end
  end

  def describe
    unless @describe
      services = client.describe_services(
        services: [service_name],
        cluster: cluster
      ).services
      if services.size > 0 && services.first.status != 'INACTIVE'
        @describe = services.first
      end
    end
    @describe
  end

  def create
    client.create_service({
      cluster: cluster,
      service_name: service_name,
      task_definition: task_definition_arn,
      network_configuration: {
        awsvpc_configuration: {
          subnets: [
            SUBNET_1_ID,
            SUBNET_2_ID
          ],
          security_groups: [
            SERVICE_SECURITY_GROUP_ID
          ],
          assign_public_ip: 'ENABLED'
        }
      },
      launch_type: 'FARGATE',
      desired_count: 1
    })
  end

  def update
    client.update_service({
      cluster: cluster,
      service: service_name,
      task_definition: task_definition_arn,
      desired_count: 1
    })
  end

  def restart_task
    client.stop_task(
      task: task_arn,
      cluster: cluster
    )
  end

  def task_arn
    # 1個しかtaskが起動していない前提
    client.list_tasks(
      cluster: cluster,
      service_name: service_name,
      desired_status: 'RUNNING',
      max_results: 1
    ).task_arns.first
  end
end

def lambda_handler(event:, context:)
  client = Aws::ECS::Client.new
 
  branch_name = event['queryStringParameters']['branch_name']
  image_tag   = "#{branch_name}_#{event['queryStringParameters']['commit_hash']}"
  puts image_tag

  task_definition = TaskDefinition.new(
    branch_name: branch_name,
    image_tag: image_tag,
    client: client
  )

  result = task_definition.register
  puts JSON.pretty_generate(result)

  service = Service.new(
    branch_name: branch_name,
    task_definition_arn: task_definition.arn,
    client: client
  )

  result = service.register.to_h
  puts JSON.pretty_generate(result)

  {
    statusCode: 200,
    headers: {},
    body: event.to_json,
    isBase64Encoded: false
  }
end
