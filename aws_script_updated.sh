#!/bin/bash
########################################################################
#
# AWS Docker Container Configuration Script, ver 2.0
# This script uses 2 EC2 instances instead of the original 3
# Copyright Systech International, 2015-2019
#
# Created: 12 Dec 2019
# Author : Robert A. Phillips
#
# Usage:
#
#
#######################################################################
set -x

#
# On Mac, do
# brew install gnu-getopt
# And set path so that /usr/local/opt/gnu-getopt/bin appears first
#
#
if [ `uname` == Darwin ]
then
	export PATH=/usr/local/opt/gnu-getopt/bin:$PATH
fi


#
# Initialize script name
#
SCRIPT_NAME=`basename ${BASH_SOURCE[0]}`

#
# AWS profile name
#
PROFILE_SPECIFIER=""

#
# Update flag
#
UPDATE=0
BACKEND_UPDATE=0
FRONTEND_UPDATE=0
RELEASE_UPDATE=0

#
# Fix flag
#
FIX=0

#
# Initialize base tags
#
TAG_CREATOR=`id | sed 's/uid=[0-9]*(\([A-Za-z0-9\._\-]*\)).*$/\1/' | cut -f 1 -d ' ' `
# The GNU date utility honors --utc.  Mac and others use -u. Use -u
TAG_DATE=`date -u +%Y%m%d-%H%M%S`
TAG_OWNER="none-specified"
TAG_RETIREMENT_DATE="none-specified"
TAG_DESCRIPTION="none-specified"

#
# Set debugging
#
DEBUG_FLAG=1

#
# China deployment flag (no ECS in China, so we
# use a special AMI for which we set tags that
# will be used to set environment variables.
# Docker images for cloud-front, cloud-back, and configurator are
# loaded to an S3 bucket, com.systechone.images
# Docker-compose files are also loaded to that bucket
#
EC2_ONLY_DEPLOYMENT=0
EC2_RELEASE_TAG=841

#
# RELEASE_TAG -- due to extreme difference between 8.5.0 and other releases
#
DEFAULT_RELEASE_TAG=860
RELEASE_TAG=""


#
# Incorta block
#
INCORTA_VOLUME_SIZE=30
INCORTA_VOLUME_TYPE=gp2
INCORTA_VOLUME_REGION=us-east-1
INCORTA_VOLUME_IOPS=100
INCORTA_DEVICE_NAME=/dev/sdf
INCORTA_VOLUME_MOUNT=/incorta/data
ADD_INCORTA_VOLUME=0

#
# Unisearch block
#
UNISEARCH_VOLUME_SIZE=30
UNISEARCH_VOLUME_TYPE=gp2
UNISEARCH_VOLUME_REGION=us-east-1
UNISEARCH_VOLUME_IOPS=100
UNISEARCH_DEVICE_NAME=/dev/sdf
UNISEARCH_VOLUME_MOUNT=/incorta/data
ADD_UNISEARCH_VOLUME=0

#
# Tier 2 Unisearch block
#
TIER2_VOLUME_SIZE=30
TIER2_VOLUME_TYPE=gp2
TIER2_VOLUME_REGION=us-east-1
TIER2_VOLUME_IOPS=100
TIER2_DEVICE_NAME=/dev/sdf
TIER2_VOLUME_MOUNT=/home/ec2-user/Storage
ADD_TIER2_VOLUME=0

#
# UNIFILE
#
UNIFILE_HOST=http://jets3t-gatekeeper:8008

#
# UNICLOUD
#
UNICLOUD_HOST=http://cloud-unicloud:8008

#
# UNISPHERE
# We count on deploying UniSphere with UniSecure
# But we have an option to change that
#
CLOUD_UNISPHERE_IP=""
#
# UNISECURE
#

# S3_FP_WRITE is needed for all containers. This allows storage of fingerprints in S3 instead of RDS to save space.
# Valid values are s3_fp_none, s3_fp_serial, s3_fp_nonserial, s3_fp_all
S3_FP_WRITE="s3_fp_none"

#
# Option variable initialization here
#
CONFIGURE_VPC=0
VPC_NAME=eng_docker
VPC_CIDR_BLOCK=10.0.0.0/16
SYSTECH_HOME_CIDR_BLOCK="47.19.206.128/26"
SYSTECH_HOME_CIDR_BLOCK_2="64.47.30.162/32"
SYSTECH_HOME_CIDR_BLOCK_3="64.47.30.161/32"

CONFIGURE_SUBNET=0
SUBNET_NAME=eng_docker
# 10.0.0.0/24 gives 256 addresses A 10.0.0.X
# May be reasonable to partition smaller -- 10.0.0.0/27 for 32
SUBNET_CIDR_BLOCK=10.0.0.0/24

CONFIGURE_SG=0
SG_NAME=eng_docker
SG_DESCRIPTION="Security group for Docker containers in VPC ${VPC_NAME}"

CONFIGURE_SQS=0
CONFIGURE_CLUSTER=0
CLUSTER_NAME=eng_docker
CONFIGURE_ROLE=0
ROLE_NAME=ecsInstanceRole
ROLE_ATTACH_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
ROLE_INLINE_POLICY_NAME="StartTask"
ASSUME_ROLE_POLICY_DOCUMENT_URL="file://C:\\Users\\bob.phillips\\Docker\\AWS_script\\ecsInstanceRolePolicy.json"
ROLE_INLINE_POLICY_DOCUMENT="file://C:\\Users\\bob.phillips\\Docker\\AWS_script\\inline-policy.json"
ROLE_INLINE_POLICY='{ \
    "Version": "2012-10-17",\
    "Statement": [\
        {\
            "Effect": "Allow",\
            "Action": [\
                "ecs:StartTask"\
            ],\
            "Resource": "*"\
        }\
    ]\
}'

CONFIGURE_KEY_PAIR=0
KEY_PAIR_NAME="systech_cloud_docker"
KEY_PAIR_FILE="$HOME/.ssh/${KEY_PAIR_NAME}.pem"

# Amazon AMI ID's for ECS Optimized images per region as of 12/22/15
# See http://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html for latest IDs
#Region	AMI Name	AMI ID
#us-east-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-6ff4bd05
#us-west-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-46cda526
#us-west-2	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-313d2150
#eu-west-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-8073d3f3
#eu-central-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-60627e0c
#ap-northeast-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-6ca38b02
#ap-southeast-1	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-a6ba79c5
#ap-southeast-2	amzn-ami-2015.09.c-amazon-ecs-optimized	ami-00e7bf63

# Future expansion
DEPLOY_UNISEARCH=0
DEPLOY_UNISECURE=0

ECS_AMI_ID=ami-6ff4bd05
CONFIGURE_INSTANCES=0
INSTANCE_TYPE=m5.large
FRONT_INSTANCE_TYPE=${INSTANCE_TYPE}
BACK_INSTANCE_TYPE=${INSTANCE_TYPE}
SEARCH_INSTANCE_TYPE=m5.large
INSTANCE_REGION=us-east-1a
INSTANCE_GROUP=DevelopmentCloud
INSTANCE_TENANCY=default
CLOUD_FRONT_ID=cloud-front
CLOUD_BACK_ID=cloud-back
SEARCH_ID=cloud-unisearch
ECS_CLEANUP_TIME=48


BLOCK_DEVICE_MAPPING_TEMPLATE='{"DeviceName": "/dev/xvdcz","Ebs": {"VolumeSize": DOCKERVOL_SIZE, "VolumeType": "DOCKERVOL_TYPE" }}'
FRONT_DOCKERVOL_SIZE=15
BACK_DOCKERVOL_SIZE=15
EC2_VOLUME_TYPE=gp3


CONFIGURE_TASK_DEFINITION=0
FRONT_END_CONTAINER_DEFINITION_FILE="file://C:\\Users\\bob.phillips\\Docker\\AWS_script\\cloud-front-task-def.json"
BACK_END_CONTAINER_DEFINITION_FILE="file://C:\\Users\\bob.phillips\\Docker\\AWS_script\\cloud-back-task-def.json"
SEARCH_CONTAINER_DEFINITION_FILE="file://C:\\Users\\bob.phillips\\Docker\\AWS_script\\search-task-def.json"
FRONT_END_TASK_DEFINITION_NAME="systech-unitrace-front"
BACK_END_TASK_DEFINITION_NAME="systech-unitrace-back"
SEARCH_TASK_DEFINITION_NAME="systech-unitrace-search"
OLD_FRONT_END_TASK_DEFINITION_NAME="systech-unitrace-front"
OLD_BACK_END_TASK_DEFINITION_NAME="systech-unitrace-back"
OLD_SUPPORT_TASK_DEFINITION_NAME="systech-unitrace-support"
OLD_SEARCH_TASK_DEFINITION_NAME="systech-unitrace-search"

CONFIGURE_SERVICE=0
SERVICE_NAME="systech-docker-container-deployment"


PRODUCTION_BUILD=true
AWS_USE_S3=true
S3_DEFAULT_REGION="us-west-1a"

#
# Pretty fonts for display
#
type -t tput >/dev/null 2>&1
if [ $? -eq 0 ]
then
	FONT_NORMAL=`tput sgr0`
	FONT_BOLD=`tput bold`
	FONT_REVERSE=`tput rev`
	FONT_STANDOUT=`tput smso`
	FONT_DIM=`tput dim`
	FONT_DEBUG=${FONT_DIM}
else
	FONT_NORMAL=""
	FONT_BOLD=""
	FONT_REVERSE=""
	FONT_STANDOUT=""
	FONT_DIM=""
	FONT_DEBUG=${FONT_DIM}
fi

function USAGE {
  echo -e \\n"${FONT_BOLD}${SCRIPT_NAME}.${FONT_NORMAL}"\\n
  echo -e "${FONT_REVERSE}Usage:${FONT_NORMAL} ${FONT_BOLD}${SCRIPT_NAME}${FONT_NORMAL}"\\n
  echo "${FONT_BOLD}The following command line switches are mandatory.${FONT_NORMAL}"
  echo "${FONT_REVERSE}--vpc-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-vpc${FONT_NORMAL} is set, this option gives the name for the newly created Virtual Private Cloud. Otherwise, it is the name of the Virtual Private Cloud to use for deployment."
  echo "${FONT_REVERSE}--subnet-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-subnet${FONT_NORMAL} is set, this option gives the name for the newly created subnet in the Virtual Private Cloud. Otherwise, it is the name of the subnet of the Virtual Private Cloud to use for deployment."
  echo "${FONT_REVERSE}--sg-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-sg${FONT_NORMAL} is set, this option gives the name for the newly created Security Group. Otherwise, it is the name of the Security Group to use for deployment."
  echo "${FONT_REVERSE}--cluster-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-cluster${FONT_NORMAL} is set, this option gives the name for the newly created Cluster. Otherwise, it is the name of the Cluster to use for deployment."
  echo "${FONT_REVERSE}--role-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-role${FONT_NORMAL} is set, this option gives the name for the newly created Role. Otherwise, it is the name of the Role to use for deployment."
  echo "${FONT_REVERSE}--key-pair-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-key-pair${FONT_NORMAL} is set, this option gives the name for the newly created Key Pair. Otherwise, it is the name of the Key Pair to use for deployment."
  echo "${FONT_REVERSE}--front-end-task-definition-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-task-definition${FONT_NORMAL} is set, this option gives the name for the newly created Front End Task Definition. Otherwise, it is the name of the Front End Task Definition to use for deployment."
  echo "${FONT_REVERSE}--back-end-task-definition-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-task-definition${FONT_NORMAL} is set, this option gives the name for the newly created Back End Task Definition. Otherwise, it is the name of the Back End Task Definition to use for deployment."
  echo "${FONT_REVERSE}--search-task-definition-name${FONT_NORMAL}  -- If ${FONT_BOLD}--configure-task-definition${FONT_NORMAL} is set, this option gives the name for the newly created Search Task Definition. Otherwise, it is the name of the Search Task Definition to use for deployment."
  echo "${FONT_REVERSE}--old-front-end-task-definition-name${FONT_NORMAL}  -- If ${FONT_BOLD}--release-update${FONT_NORMAL} is set, this option gives the name for the existing Front End Task Definition to be replaced."
  echo "${FONT_REVERSE}--old-back-end-task-definition-name${FONT_NORMAL}  -- If ${FONT_BOLD}--release-update${FONT_NORMAL} is set, this option gives the name for the existing Back End Task Definition to be replaced."
  echo "${FONT_REVERSE}--old-support-task-definition-name${FONT_NORMAL}  -- This option gives the name for the existing Support Task Definition to be replaced."
  echo "${FONT_REVERSE}--old-search-task-definition-name${FONT_NORMAL}  -- This option gives the name for the existing Search Task Definition to be replaced."
  echo "${FONT_REVERSE}--s3-keys${FONT_NORMAL} JSON string of S3 Keys. Format is '{\"us-east\": {\"access_key\": \"AKIAXYZZYYYZYYZRUSHQ\", \"secret_key\":\"Nb2ruserIouSTHiscANN0t5TaNDfOr3VerWowZZY\"}}'"
  echo "${FONT_REVERSE}--s3-root${FONT_NORMAL} S3 root directory name"
  echo "${FONT_REVERSE}--aws-storage-bucket-name${FONT_NORMAL} S3 root bucket name"
  echo "${FONT_REVERSE}--aws-cloudfront-url${FONT_NORMAL} S3 Cloudfront URL"
  echo "${FONT_REVERSE}--aws-cloudfront-keypair-id${FONT_NORMAL} S3 Cloudfront key-pair ID"
  echo \\n"${FONT_BOLD}The following command line switches are optional.${FONT_NORMAL}"
  echo "${FONT_REVERSE}--profile${FONT_NORMAL}  -- Provides the name of the AWS CLI configuration profile to use. If you aren't using AWS CLI profiles, don't worry about this."
  echo "${FONT_REVERSE}--release-update${FONT_NORMAL}  -- Indicates that we are updating an existing installation to a new release.  Create NOTHING. Stop running front-end and back-end jobs, and start new tasks only."
  echo "${FONT_REVERSE}--update${FONT_NORMAL}  -- Indicates that we are updating an existing installation.  Create NOTHING. Stop running front-end and back-end jobs, and start new tasks only."
  echo "${FONT_REVERSE}--backend-update${FONT_NORMAL}  -- Indicates that we are updating only the back-end an existing installation.  Create NOTHING. Stop running back-end jobs, and start new task only."
  echo "${FONT_REVERSE}--frontend-update${FONT_NORMAL}  -- Indicates that we are updating only the front-end an existing installation.  Create NOTHING. Stop running front-end processes, and start new task only."
  echo "${FONT_REVERSE}--update${FONT_NORMAL}  -- Indicates that we are updating an existing installation.  Create NOTHING. Stop running front-end and back-end jobs, and start new tasks only."
  echo "${FONT_REVERSE}--fix${FONT_NORMAL}  -- Indicates that we are fixing an existing installation by re-creating front-end and back-end containers and running new tasks"
  echo "${FONT_REVERSE}--ec2only${FONT_NORMAL}  -- Indicates that we are eschewing AWS EC2 Container services in favor of running Docker directly from a custom AMI (used in China)"
  echo "${FONT_REVERSE}--ec2release${FONT_NORMAL}  -- Release tag (e.g. 841) to be used as a suffix on flattened Docker image files for EC2-only deployment."
  echo "${FONT_REVERSE}--release${FONT_NORMAL}  -- Release tag (e.g. 841) to be used for general deployment. Will try to obtain from task definitions. Use current as default"
  echo "${FONT_REVERSE}--unifile-host${FONT_NORMAL}  -- UniFile host URL with name and port -- e.g. http://10.0.4.4:8008."
  echo "${FONT_REVERSE}--unicloud-host${FONT_NORMAL}  -- UniCloud host URL with name and port -- e.g. http://10.0.4.2:8008."
  echo "${FONT_REVERSE}--front-dockervol-size${FONT_NORMAL}  -- Specifies storage size in GB for Front End Docker volume. MUST BE > 30."
  echo "${FONT_REVERSE}--back-dockervol-size${FONT_NORMAL}  -- Specifies storage size in GB for Back End Docker volume. MUST BE > 30."
  echo "${FONT_REVERSE}--add-incorta-volume${FONT_NORMAL}  -- Indicates that we are adding additional storage for Incorta."
  echo "${FONT_REVERSE}--incorta-volume-size${FONT_NORMAL}  -- Specifies storage size in GB for Incorta."
  echo "${FONT_REVERSE}--incorta-volume-type${FONT_NORMAL}  -- Specifies AWS volume type for Incorta storage. Values 'gp2', 'standard', and 'io1' are valid."
  echo "${FONT_REVERSE}--incorta-volume-iops${FONT_NORMAL}  -- Specifies AWS volume IOPS value for Incorta storage of type 'io1'."
  echo "${FONT_REVERSE}--incorta-volume-region${FONT_NORMAL}  -- Specifies AWS region for the volume."
  echo "${FONT_REVERSE}--incorta-device-name${FONT_NORMAL}  -- Specifies Linux device for the volume."
  echo "${FONT_REVERSE}--incorta-volume-mount${FONT_NORMAL}  -- Specifies Linux mount point for the volume."
  echo "${FONT_REVERSE}--add-tier2-volume${FONT_NORMAL}  -- Indicates that we are adding additional storage to the front-end instance for Tier 2 Unisearch."
  echo "${FONT_REVERSE}--tier2-volume-size${FONT_NORMAL}  -- Specifies storage size in GB for Tier 2 Unisearch."
  echo "${FONT_REVERSE}--tier2-volume-type${FONT_NORMAL}  -- Specifies AWS volume type for Tier 2 Unisearch storage. Values 'gp2', 'standard', and 'io1' are valid."
  echo "${FONT_REVERSE}--tier2-volume-iops${FONT_NORMAL}  -- Specifies AWS volume IOPS value for Tier 2 Unisearch storage of type 'io1'."
  echo "${FONT_REVERSE}--tier2-volume-region${FONT_NORMAL}  -- Specifies AWS region for the Tier 2 Unisearch volume."
  echo "${FONT_REVERSE}--tier2-device-name${FONT_NORMAL}  -- Specifies Linux device for the Tier 2 Unisearch volume."
  echo "${FONT_REVERSE}--tier2-volume-mount${FONT_NORMAL}  -- Specifies Linux mount point for the Tier 2 Unisearch volume."
  echo "${FONT_REVERSE}--add-unisearch-volume${FONT_NORMAL}  -- Indicates that we are adding additional storage for Unisearch."
  echo "${FONT_REVERSE}--unisearch-volume-size${FONT_NORMAL}  -- Specifies storage size in GB for Unisearch."
  echo "${FONT_REVERSE}--unisearch-volume-type${FONT_NORMAL}  -- Specifies AWS volume type for Unisearch storage. Values 'gp2', 'standard', and 'io1' are valid."
  echo "${FONT_REVERSE}--unisearch-volume-iops${FONT_NORMAL}  -- Specifies AWS volume IOPS value for Unisearch storage of type 'io1'."
  echo "${FONT_REVERSE}--unisearch-volume-region${FONT_NORMAL}  -- Specifies AWS region for the Unisearch volume."
  echo "${FONT_REVERSE}--unisearch-device-name${FONT_NORMAL}  -- Specifies Linux device for the Unisearch volume."
  echo "${FONT_REVERSE}--unisearch-volume-mount${FONT_NORMAL}  -- Specifies Linux mount point for the Unisearch volume."
  echo "${FONT_REVERSE}--deploy-unisearch${FONT_NORMAL}  -- Indicates that have a UniSearch instance to deploy or that has been deployed"
  echo "${FONT_REVERSE}--deploy-unisecure${FONT_NORMAL}  -- Indicates that have a UniSecure instance to deploy or that has been deployed"
  echo "${FONT_REVERSE}--non-production${FONT_NORMAL}  -- Indicates that we are creating a debuggable installation."
  echo "${FONT_REVERSE}--configure-vpc${FONT_NORMAL}  -- When set, indicates that a new Virtual Private Cloud should be created."
  echo "${FONT_REVERSE}--vpc-cidr${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-vpc${FONT_NORMAL} is set. Specifies the size of the cloud created. Default is ${FONT_BOLD}${VPC_CIDR_BLOCK}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--configure-subnet${FONT_NORMAL}  -- When set, indicates that a new subnet of the Virtual Private Cloud should be created."
  echo "${FONT_REVERSE}--subnet-cidr${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-subnet${FONT_NORMAL} is set. Specifies the size of the subnet created. Default is ${FONT_BOLD}${SUBNET_CIDR_BLOCK}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--configure-sg${FONT_NORMAL}  -- When set, indicates that a new Security Group should be created."
  echo "${FONT_REVERSE}--sg-description${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-sg${FONT_NORMAL} is set. Specifies a description for the Security Group. The default value is ${FONT_BOLD}${SG_DESCRIPTION}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--configure-sqs${FONT_NORMAL}  -- When set, indicates that a new SQS should be created."
  echo "${FONT_REVERSE}--configure-cluster${FONT_NORMAL}  -- When set, indicates that a new Cluster should be created."
  echo "${FONT_REVERSE}--configure-role${FONT_NORMAL}  -- When set, indicates that a new IAM Role should be created."
  echo "${FONT_REVERSE}--configure-key-pair${FONT_NORMAL}  -- When set, indicates that a new Key Pair should be created."
  echo "${FONT_REVERSE}--key-pair-file${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-key-pair${FONT_NORMAL} is set. Specifies a local file to be used to store the key to be used to connect to deployed instances."
  echo "${FONT_REVERSE}--configure-instances${FONT_NORMAL}  -- When set, indicates that a new set of EC2 Instances should be created to hold the Docker containers."
  echo "${FONT_REVERSE}--instance-image-id${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies an AMI to be used to initialize the deployed instances. The correct choice is  an AMI optimized for EC2 Docker operations, but the image ID that choice changes from region to region.  The default value is the Optimized image for us-east-1a, ${FONT_BOLD}${ECS_AMI_ID}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--instance-type${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies an AWS type identifier that describes the image size and capabilities.  Used when front and back instances are  the same type. The default value is ${FONT_BOLD}${INSTANCE_TYPE}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--front-instance-type${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies an AWS type identifier that describes the image size and capabilities.  Overrides --instance-type. The default value is ${FONT_BOLD}${INSTANCE_TYPE}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--back-instance-type${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies an AWS type identifier that describes the image size and capabilities.  Overrides --instance-type. The default value is ${FONT_BOLD}${INSTANCE_TYPE}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--search-instance-type${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies an AWS type identifier that describes the image size and capabilities of the search instance.  The default value is ${FONT_BOLD}${SEARCH_INSTANCE_TYPE}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--instance-region${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies the AWS region to which the instances are to be deployed. This value must agree with the implicit region definition employed to create all other features used. The default value is ${FONT_BOLD}${INSTANCE_REGION}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--instance-group${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies a name to be used to identify the group of created instances. The default value is ${FONT_BOLD}${INSTANCE_GROUP}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--cloud-front-hostid${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies a host name to be used to identify the instance that will support the Cloud Front End.  The default value is ${FONT_BOLD}${CLOUD_FRONT_ID}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--cloud-back-hostid${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies a host name to be used to identify the instance that will support the Cloud Back End.  The default value is ${FONT_BOLD}${CLOUD_BACK_ID}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--search-hostid${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-instances${FONT_NORMAL} is set. Specifies a host name to be used to identify the instance that will support the Search Facilities \(UniSearch\). The default value is ${FONT_BOLD}${SEARCH_ID}${FONT_NORMAL}."
  echo "${FONT_REVERSE}--configure-task-definition${FONT_NORMAL}  -- When set, indicates that a new Task Definition should be created."
  echo "${FONT_REVERSE}--back-end-container-definition-file${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-task-definition${FONT_NORMAL} is set. Specifies a local file that describes the Docker containers to be created for the back-end instances. The file should have descriptions for at least the following containers: cloud-back"
  echo "${FONT_REVERSE}--front-end-container-definition-file${FONT_NORMAL}  -- Only valid when ${FONT_BOLD}--configure-task-definition${FONT_NORMAL} is set. Specifies a local file that describes the Docker containers to be created for the front-end instances. The file should have descriptions for at least the following containers: cloud-front"
  echo "${FONT_REVERSE}--s3-default-region${FONT_NORMAL} Sets the default S3 region.  If not set, us-west-1a is used."
  echo "${FONT_REVERSE}--s3-all-regions${FONT_NORMAL} Sets the available S3 regions.  If not set, ${FONT_BOLD}['ap-northeast', 'ap-southeast', 'eu-central', 'eu-west', 'sa-east','us-west']${FONT_NORMAL} is used."
  echo "${FONT_REVERSE}--owner${FONT_NORMAL} Sets the owner tag."
  echo "${FONT_REVERSE}--retirement-date${FONT_NORMAL} Sets date by which the instance should be no longer needed."
  echo "${FONT_REVERSE}--description${FONT_NORMAL} Sets the description/purpose tag for the created instances."
  echo "${FONT_REVERSE}--unisphere-ip${FONT_NORMAL} Sets the IP address of the UniSphere host."
  echo "${FONT_REVERSE}--ecs-cleanup-time${FONT_NORMAL} Sets the ECS Task Cleanup duration inside Instance."
  echo "${FONT_REVERSE}--s3-fp-write${FONT_NORMAL} This allows storage of fingerprints in S3 instead of RDS to save space. Valid values are s3_fp_none, s3_fp_serial, s3_fp_nonserial, s3_fp_all ."
  echo -e \\n"Example:\\n ${FONT_BOLD}${SCRIPT_NAME} --non-production --deploy-unisearch --profile ENG-PERF --configure-vpc --vpc-name MyVPC \
 --vpc-cidr 10.0.0.0/16 --configure-subnet --subnet-name MySubnet --subnet-cidr 10.0.0.0/16 \
 --configure-sg --sg-name MySecurityGroup \
 --sg-description \"This is my Security Group\" --configure-sqs --configure-cluster \
 --unifile-host http://unifile.systechcloud.net:8008 \
 --unicloud-host http://unicloud.systechcloud.net:8008 \
 --add-incorta-volume --incorta-volume-size 50 incorta-volume-type iops --incorta-volume-iops 200 --incorta-volume-region us-east-1 \
 --incorta-device-name /dev/sdf --incorta-volume-mount /home/ec2-user/Storage/incorta \
 --add-unisearch-volume --unisearch-volume-size 2000 --unisearch-volume-type iops --unisearch-volume-iops 1000 --unisearch-volume-region us-east-1 \
 --unisearch-device-name /dev/sdf --unisearch-volume-mount /mysql-files \
 --add-tier2-volume --tier2-volume-size 100 --tier2-volume-type iops --tier2-volume-iops 1000 --tier2-volume-region us-east-1 \
 --tier2-device-name /dev/sdf --tier2-volume-mount /home/ec2-user/Storage \
 --ecs-cleanup-time 72 \
 --cluster-name MyCluster --configure-role --role-name MyEC2Role \
 --configure-key-pair --key-pair-name MyKeyPair \
 --key-pair-file /home/me/mykey.pem --configure-instances \
 --instance-image-id ami-00a7bf63 --instance-type m3.large --search-instance-type m3.large \
 --instance-region ap-southeast-2 --instance-group MyInstances \
 --cloud-front-hostid cloud-front --cloud-back-hostid cloud-back \
 --search-hostid cloud-unisearch --configure-task-definition \
 --front-end-task-definition-name MyFrontEndTaskDef \
 --back-end-task-definition-name MyBackEndTaskDef \
 --search-task-definition-name MySearchTaskDef \
 --back-end-container-definition-file /home/me/my-back-container-definitions.json \
 --front-end-container-definition-file /home/me/my-front-container-definitions.json \
 --search-container-definition-file /home/me/my-search-container-definitions.json \
 --s3-default-region us-west-1a --s3-keys '{\"us-east\": {\"access_key\": \"AKIAXYZZYYYZYYZRUSHQ\", \"secret_key\":\"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\"}}' \
 --s3-all-regions '[\"ap-northeast\", \"us-east\"]' --s3-root engqacloud820 \
 --aws-storage-bucket-name engqacloud820 --aws-cloudfront-url \"dsomething888xxx.cloudfront.net\" \
 --s3-fp-write s3_fp_none \
 --aws-cloudfront-keypair-id \"AKIAXYZZYYYZYYZRUSHQ\" --owner \"Dave Henderson\" --retirement-date \"2017-12-31\" --description \"Sample Demonstration System\" "\\n
}


### Start getopt code ###
# Execute getopt
ARGS=$(getopt -l "profile:,non-production,update,backend-update,frontend-update,release-update,fix,deploy-unisearch,deploy-unisecure,ec2only,ec2release:,release:,configure-vpc,vpc-name:,\
	vpc-cidr:,configure-subnet,subnet-cidr:,subnet-name:,configure-sg,\
	sg-name:,sg-description:,configure-sqs,configure-cluster,cluster-name:,\
	configure-role,role-name:,configure-key-pair,key-pair-name:,\
	key-pair-file:,configure-instances,instance-image-id:,instance-type:,front-instance-type:,back-instance-type:,search-instance-type:,\
	instance-region:,instance-group:,cloud-front-hostid:,\
	cloud-back-hostid:,search-hostid:,configure-task-definition,\
	old-front-end-task-definition-name:,old-back-end-task-definition-name:,\
	old-support-task-definition-name:,old-search-task-definition-name:,\
	front-end-task-definition-name:,back-end-task-definition-name:,\
	search-task-definition-name:,\
	front-end-container-definition-file:,\ back-end-container-definition-file:,\
	search-container-definition-file:,\
	s3-default-region:,s3-keys:,s3-all-regions:,s3-root:,aws-storage-bucket-name:,\
	aws-cloudfront-url:,aws-cloudfront-keypair-id:,unifile-host:,unicloud-host:,\
	add-incorta-volume,incorta-volume-size:,incorta-volume-type:,incorta-volume-iops:,\
	incorta-volume-region:,incorta-device-name:,incorta-volume-mount:,\
	add-unisearch-volume,unisearch-volume-size:,unisearch-volume-type:,unisearch-volume-iops:,\
	unisearch-volume-region:,unisearch-device-name:,unisearch-volume-mount:,\
	add-tier2-volume,tier2-volume-size:,tier2-volume-type:,tier2-volume-iops:,\
	tier2-volume-region:,tier2-device-name:,tier2-volume-mount:,\
	front-dockervol-size:,back-dockervol-size:,\
	retirement-date:,owner:,cognitourl:,lamdaurl:,alerturl:,coguser:,cogpass:,cogclient:,description:,unisphere-ip:,\
	ecs-cleanup-time:,s3-fp-write:" -n "getopt.sh" -- "?" "$@");

#Bad arguments
if [ $? -ne 0 ];
then
  USAGE
  exit 1
fi

eval set -- "$ARGS";

while true; do
  echo "Examining argument $1"
  case "$1" in
    --profile)
      shift;
      if [ -n "$1" ]; then
        PROFILE_SPECIFIER=" --profile $1 ";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --update)
      UPDATE=1;
      shift;
      ;;
    --backend-update)
      BACKEND_UPDATE=1;
      shift;
      ;;
    --frontend-update)
      FRONTEND_UPDATE=1;
      shift;
      ;;
    --release-update)
      UPDATE=1;
      RELEASE_UPDATE=1;
      shift;
      ;;
    --fix)
      FIX=1;
      shift;
      ;;
    --deploy-unisearch)
      DEPLOY_UNISEARCH=1;
      shift;
      ;;
    --deploy-unisecure)
      DEPLOY_UNISECURE=1;
      shift;
      ;;
    --ec2only)
      EC2_ONLY_DEPLOYMENT=1;
      shift;
      ;;
    --ec2release)
      shift;
      if [ -n "$1" ]; then
        EC2_RELEASE_TAG="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --release)
      shift;
      if [ -n "$1" ]; then
        RELEASE_TAG="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --non-production)
      PRODUCTION_BUILD=false;
      shift;
      ;;
    --configure-vpc)
      CONFIGURE_VPC=1;
      shift;
      ;;
    --vpc-name)
      shift;
      if [ -n "$1" ]; then
        VPC_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --vpc-cidr)
      shift;
      if [ -n "$1" ]; then
        VPC_CIDR_BLOCK="$1";
        shift;
      else
	USAGE;
	exit 1
      fi
      ;;
    --configure-subnet)
      CONFIGURE_SUBNET=1;
      shift;
      ;;
    --subnet-name)
      shift;
      if [ -n "$1" ]; then
        SUBNET_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --subnet-cidr)
      shift;
      if [ -n "$1" ]; then
        SUBNET_CIDR_BLOCK="$1";
        shift;
      else
	USAGE;
	exit 1
      fi
      ;;
    --configure-sg)
      CONFIGURE_SG=1;
      shift;
      ;;
    --sg-name)
      shift;
      if [ -n "$1" ]; then
        SG_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --sg-description)
      shift;
      if [ -n "$1" ]; then
        SG_DESCRIPTION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
	--configure-sqs)
      CONFIGURE_SQS=1;
      shift;
      ;;
    --configure-cluster)
      CONFIGURE_CLUSTER=1;
      shift;
      ;;
    --cluster-name)
      shift;
      if [ -n "$1" ]; then
        CLUSTER_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --configure-role)
      CONFIGURE_ROLE=1;
      shift;
      ;;
    --role-name)
      shift;
      if [ -n "$1" ]; then
        ROLE_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --configure-key-pair)
      CONFIGURE_KEY_PAIR=1;
      shift;
      ;;
    --key-pair-name)
      shift;
      if [ -n "$1" ]; then
        KEY_PAIR_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --key-pair-file)
      shift;
      if [ -n "$1" ]; then
        KEY_PAIR_FILE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --configure-instances)
      CONFIGURE_INSTANCES=1;
      shift;
      ;;
    --instance-image-id)
      shift;
      if [ -n "$1" ]; then
        ECS_AMI_ID="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --instance-type)
      shift;
      if [ -n "$1" ]; then
        INSTANCE_TYPE="$1";
        FRONT_INSTANCE_TYPE="${INSTANCE_TYPE}";
        BACK_INSTANCE_TYPE="${INSTANCE_TYPE}";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --front-instance-type)
      shift;
      if [ -n "$1" ]; then
        FRONT_INSTANCE_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --back-instance-type)
      shift;
      if [ -n "$1" ]; then
        BACK_INSTANCE_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --search-instance-type)
      shift;
      if [ -n "$1" ]; then
        SEARCH_INSTANCE_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --instance-region)
      shift;
      if [ -n "$1" ]; then
        INSTANCE_REGION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --instance-group)
      shift;
      if [ -n "$1" ]; then
        INSTANCE_GROUP="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --cloud-front-hostid)
      shift;
      if [ -n "$1" ]; then
        CLOUD_FRONT_ID="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --cloud-back-hostid)
      shift;
      if [ -n "$1" ]; then
        CLOUD_BACK_ID="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --search-hostid)
      shift;
      if [ -n "$1" ]; then
        SEARCH_ID="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --configure-task-definition)
      CONFIGURE_TASK_DEFINITION=1;
      shift;
      ;;
    --front-end-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        FRONT_END_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --back-end-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        BACK_END_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --search-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        SEARCH_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --old-front-end-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        OLD_FRONT_END_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --old-back-end-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        OLD_BACK_END_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --old-support-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        OLD_SUPPORT_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --old-search-task-definition-name)
      shift;
      if [ -n "$1" ]; then
        OLD_SEARCH_TASK_DEFINITION_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --back-end-container-definition-file)
      shift;
      if [ -n "$1" ]; then
        BACK_END_CONTAINER_DEFINITION_FILE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --front-end-container-definition-file)
      shift;
      if [ -n "$1" ]; then
        FRONT_END_CONTAINER_DEFINITION_FILE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --search-container-definition-file)
      shift;
      if [ -n "$1" ]; then
        SEARCH_CONTAINER_DEFINITION_FILE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --s3-default-region)
      shift;
      if [ -n "$1" ]; then
        S3_DEFAULT_REGION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --s3-keys)
      shift;
      if [ -n "$1" ]; then
        S3_KEYS="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --s3-all-regions)
      shift;
      if [ -n "$1" ]; then
        S3_ALL_REGIONS="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --s3-root)
      shift;
      if [ -n "$1" ]; then
        S3_ROOT="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --aws-storage-bucket-name)
      shift;
      if [ -n "$1" ]; then
        AWS_STORAGE_BUCKET_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --aws-cloudfront-url)
      shift;
      if [ -n "$1" ]; then
        AWS_CLOUDFRONT_URL="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --aws-cloudfront-keypair-id)
      shift;
      if [ -n "$1" ]; then
        AWS_CLOUDFRONT_KEYPAIR_ID="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unifile-host)
      shift;
      if [ -n "$1" ]; then
        UNIFILE_HOST="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unicloud-host)
      shift;
      if [ -n "$1" ]; then
        UNICLOUD_HOST="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --add-incorta-volume)
      ADD_INCORTA_VOLUME=1;
      shift;
      ;;
    --incorta-volume-size)
      shift;
      if [ -n "$1" ]; then
        INCORTA_VOLUME_SIZE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --incorta-volume-type)
      shift;
      if [ -n "$1" ]; then
        INCORTA_VOLUME_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --incorta-volume-iops)
      shift;
      if [ -n "$1" ]; then
        INCORTA_VOLUME_IOPS="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --incorta-volume-region)
      shift;
      if [ -n "$1" ]; then
        INCORTA_VOLUME_REGION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --incorta-device-name)
      shift;
      if [ -n "$1" ]; then
        INCORTA_DEVICE_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --incorta-volume-mount)
      shift;
      if [ -n "$1" ]; then
        INCORTA_VOLUME_MOUNT="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --add-unisearch-volume)
      ADD_UNISEARCH_VOLUME=1;
      shift;
      ;;
    --unisearch-volume-size)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_VOLUME_SIZE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisearch-volume-type)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_VOLUME_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisearch-volume-iops)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_VOLUME_IOPS="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisearch-volume-region)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_VOLUME_REGION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisearch-device-name)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_DEVICE_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisearch-volume-mount)
      shift;
      if [ -n "$1" ]; then
        UNISEARCH_VOLUME_MOUNT="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --add-tier2-volume)
      ADD_TIER2_VOLUME=1;
      shift;
      ;;
    --tier2-volume-size)
      shift;
      if [ -n "$1" ]; then
        TIER2_VOLUME_SIZE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --tier2-volume-type)
      shift;
      if [ -n "$1" ]; then
        TIER2_VOLUME_TYPE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --tier2-volume-iops)
      shift;
      if [ -n "$1" ]; then
        TIER2_VOLUME_IOPS="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --tier2-volume-region)
      shift;
      if [ -n "$1" ]; then
        TIER2_VOLUME_REGION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --tier2-device-name)
      shift;
      if [ -n "$1" ]; then
        TIER2_DEVICE_NAME="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --tier2-volume-mount)
      shift;
      if [ -n "$1" ]; then
        TIER2_VOLUME_MOUNT="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --ecs-cleanup-time)
      shift;
      if [ -n "$1" ]; then
        ECS_CLEANUP_TIME="$1";
        shift;
      else
	ECS_CLEANUP_TIME=48;
	shift;
      fi
	  ;;
	--cognitourl)
	  shift;
	  if [ -n "$1" ]; then
	    COGNI_URL="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
	--lamdaurl)
	  shift;
	  if [ -n "$1" ]; then
	    LAMDA_URL="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
	--coguser)
	  shift;
	  if [ -n "$1" ]; then
	    COG_USER="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
	--cogpass)
	  shift;
	  if [ -n "$1" ]; then
	    COG_PASS="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
	--cogclient)
	  shift;
	  if [ -n "$1" ]; then
	    COG_CLIENT="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
	--alerturl)
	  shift;
	  if [ -n "$1" ]; then
	    ALERT_URL="$1";
		shift;
	  else
	USAGE;
	exit 1;
	  fi
      ;;
    --owner)
      shift;
      if [ -n "$1" ]; then
        TAG_OWNER="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --retirement-date)
      shift;
      if [ -n "$1" ]; then
        TAG_RETIREMENT_DATE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --description)
      shift;
      if [ -n "$1" ]; then
        TAG_DESCRIPTION="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --unisphere-ip)
      shift;
      if [ -n "$1" ]; then
        CLOUD_UNISPHERE_IP="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --front-dockervol-size)
      shift;
      if [ -n "$1" ]; then
        FRONT_DOCKERVOL_SIZE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --back-dockervol-size)
      shift;
      if [ -n "$1" ]; then
        BACK_DOCKERVOL_SIZE="$1";
        shift;
      else
	USAGE;
	exit 1;
      fi
      ;;
    --s3-fp-write)
      shift;
      if [ -n "${1}" ]; then
	  	S3_FP_WRITE="${1}";
		shift;
      fi
      ;;
    --help)
      USAGE;
      exit 1;
      ;;
    --)
      shift;
      break;
      ;;
  esac
done

### End getopt code ###

function debug {
  echo -e \\n"${FONT_DEBUG} $* ${FONT_NORMAL}"\\n
}

if [ ${UPDATE} -eq 1 -o ${BACKEND_UPDATE} -eq 1 -o ${FRONTEND_UPDATE} -eq 1 ]
then
	echo "--update, --frontend-updated, or --backend-update is specified. Ignoring any options to create anything!"
	CONFIGURE_VPC=0
	CONFIGURE_SUBNET=0
	CONFIGURE_SG=0
	CONFIGURE_CLUSTER=0
	CONFIGURE_ROLE=0
	CONFIGURE_KEY_PAIR=0
	CONFIGURE_INSTANCES=0
	CONFIGURE_TASK_DEFINITION=0
	CONFIGURE_SERVICE=0
	ADD_INCORTA_VOLUME=0
	ADD_TIER2VOLUME=0
elif [ ${FIX} -eq 1 ]
then
	echo "--fix is specified."
	CONFIGURE_VPC=0
	CONFIGURE_SUBNET=0
	CONFIGURE_SG=0
	CONFIGURE_CLUSTER=0
	CONFIGURE_ROLE=0
	CONFIGURE_KEY_PAIR=0
	CONFIGURE_INSTANCES=1
	CONFIGURE_TASK_DEFINITION=0
	CONFIGURE_SERVICE=0
	ADD_INCORTA_VOLUME=0
	ADD_TIER2VOLUME=0

fi

#
# Look for release from task definition names, if not set
#
if [ -z ${RELEASE_TAG} ]
then
	R1=`echo ${BACK_END_TASK_DEFINITION_NAME} | sed -e 's/[A-Za-z_\-]*//'`
	R2=`echo ${FRONT_END_TASK_DEFINITION_NAME} | sed -e 's/[A-Za-z_\-]*//'`
	if [ "$R1" != "$R2" ]
	then
		RELEASE_TAG="${DEFAULT_RELEASE_TAG}"
	else
		RELEASE_TAG="$R1"
	fi
fi



########################################################################
#
# Create VPC
#
########################################################################
VPC_ID=""

if [ ${CONFIGURE_VPC} -eq 1 ]
then
	debug "Configuring VPC"

	debug "VPC create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-vpc --dry-run --cidr-block "${VPC_CIDR_BLOCK}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "VPC create -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-vpc --cidr-block "${VPC_CIDR_BLOCK}" --output text --query 'Vpc.VpcId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	VPC_ID=`echo ${RESULT} |tr -d \\\\015`
	if [ "${VPC_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain VPC ID for created VPC ${VPC_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Created VPC has name ${VPC_NAME} and ID ${VPC_ID}"

	#
	# Enable the DNS support -- without this, certain ECS Instance
	# operations (registration) will FAIL!
	# According to Amazon documentation, one cannot enable DNS support and enable DNS hostnames
	# in the same modify-vpc-attribute command, so we need to issue 2 separate commands.
	#
	debug "Enabling DNS Support on VPC ${VPC_NAME}"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-support "{\"Value\":true}" `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	debug "Enabling DNS Hostnames on VPC ${VPC_NAME}"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-hostnames "{\"Value\":true}" `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Created VPC ${VPC_NAME} now has DNS support and will issue a hostname to instances"

	#
	# Add Tags
	#
	debug "Tagging VPC -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${VPC_ID}" --tags Key=Name,Value="${VPC_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging VPC -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --resources "${VPC_ID}" --tags Key=Name,Value="${VPC_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
else
	debug "Using existing VPC of name ${VPC_NAME}"
	# So we are using an existing VPC of VPC_NAME. Find its ID and set VPC_ID
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-vpcs --filters Name=tag:Name,Values="${VPC_NAME}" --output text --query 'Vpcs[0].VpcId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	VPC_ID=`echo ${RESULT} |tr -d \\\\015`
	if [ "${VPC_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain VPC ID for ${VPC_NAME}${FONT_NORMAL}\\n
		exit 1
	fi

	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-vpcs --filters Name=tag:Name,Values="${VPC_NAME}" --output text --query 'Vpcs[0].CidrBlock' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	VPC_CIDR_BLOCK=`echo ${RESULT} |tr -d \\\\015`
	if [ "${VPC_CIDR_BLOCK}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain VPC CIDR for ${VPC_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Found VPC with name ${VPC_NAME}, ID ${VPC_ID}, and CIDR block ${VPC_CIDR_BLOCK}"
fi

########################################################################
#
# Create Subnet
#
########################################################################
SUBNET_ID=""

if [ ${CONFIGURE_SUBNET} -eq 1 ]
then
	debug "Configuring Subnet"

	debug "Subnet create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-subnet --dry-run --vpc-id "${VPC_ID}" --cidr-block "${SUBNET_CIDR_BLOCK}" --availability-zone "${INSTANCE_REGION}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Subnet create -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${SUBNET_CIDR_BLOCK}" --availability-zone "${INSTANCE_REGION}" --output text --query 'Subnet.SubnetId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	SUBNET_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${SUBNET_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Subnet ID for created subnet ${SUBNET_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Created Subnet has  ID ${SUBNET_ID}"

	#
	# Add Tags
	#
	debug "Tagging Subnet -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${SUBNET_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging Subnet -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --resources "${SUBNET_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
else
	debug "Using existing Subnet of name ${SUBNET_NAME}"
	# So we are using an existing Subnet of Subnet_NAME. Find its ID and set VPC_ID
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-subnets --filters Name=tag:Name,Values="${SUBNET_NAME}" --output text --query 'Subnets[0].SubnetId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	SUBNET_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${SUBNET_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Subnet ID for ${SUBNET_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Found Subnet with name ${SUBNET_NAME} and ID ${SUBNET_ID}"
	# Now get Subnet CIDR Block
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-subnets --filters Name=tag:Name,Values="${SUBNET_NAME}" --output text --query 'Subnets[0].CidrBlock' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	SUBNET_CIDR_BLOCK=`echo ${RESULT} | tr -d \\\\015`
	if [ "${SUBNET_CIDR_BLOCK}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Subnet CIDR Block for ${SUBNET_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Subnet with name ${SUBNET_NAME} and ID ${SUBNET_ID} has CIDR block ${SUBNET_CIDR_BLOCK}"

fi

########################################################################
#
# Create Internet Gateway, but only if creating a VPC
#
########################################################################
INTERNET_GATEWAY_ID=""

if [ ${CONFIGURE_VPC} -eq 1 ]
then
	debug "Configuring Internet Gateway"

	debug "Internet Gateway create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-internet-gateway --dry-run 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Internet Gateway create -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	INTERNET_GATEWAY_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${INTERNET_GATEWAY_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain ID for created internet gateway ${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Created Internet Gateway has  ID ${INTERNET_GATEWAY_ID}"

	#
	# Add Tags
	#
	debug "Tagging Internet Gateway -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${INTERNET_GATEWAY_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging Internet Gateway -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --resources "${INTERNET_GATEWAY_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}"  Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	#
	# Now attach Gateway to VPC
	#
	debug "Attach Internet Gateway to VPC ${VPC_NAME}-- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 attach-internet-gateway --dry-run --internet-gateway-id "${INTERNET_GATEWAY_ID}" --vpc-id "${VPC_ID}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Attach Internet Gateway to VPC ${VPC_NAME}-- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 attach-internet-gateway --internet-gateway-id "${INTERNET_GATEWAY_ID}" --vpc-id "${VPC_ID}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Internet Gateway ${INTERNET_GATEWAY_ID} attached to VPC ${VPC_NAME}"

else
	debug "Using existing Internet Gateway associated with VPC ${VPC_NAME}"
	# So we are using an existing VPC of VPC ID
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="${VPC_ID}" --output text --query 'InternetGateways[0].InternetGatewayId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	INTERNET_GATEWAY_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${INTERNET_GATEWAY_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Internet Gateway  for VPC ${VPC_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Found Internet Gateway with ID ${INTERNET_GATEWAY_ID}"
fi

########################################################################
#
# Create Route Table, but only if creating a subnet
#
########################################################################
ROUTE_TABLE_ID=""

if [ ${CONFIGURE_SUBNET} -eq 1 ]
then
	debug "Configuring Route Table"

	debug "Route Table create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-route-table --dry-run --vpc-id "${VPC_ID}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Route Table create -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-route-table --vpc-id "${VPC_ID}" --output text --query 'RouteTable.RouteTableId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	ROUTE_TABLE_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${ROUTE_TABLE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain ID for created route table ${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Created Route Table has  ID ${ROUTE_TABLE_ID}"

	#
	# Add Tags
	#
	debug "Tagging Route Table -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${ROUTE_TABLE_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging Route Table -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --resources "${ROUTE_TABLE_ID}" --tags Key=Name,Value="${SUBNET_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	#
	# Now add Internet Gateway to Route Table
	#
	debug "Connect Internet Gateway to Route Table -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-route --dry-run --route-table-id "${ROUTE_TABLE_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${INTERNET_GATEWAY_ID}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Connect Internet Gateway to Route Table -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-route --route-table-id "${ROUTE_TABLE_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${INTERNET_GATEWAY_ID}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Internet Gateway ${INTERNET_GATEWAY_ID} connected to Route Table"

	#
	# Now add Route Table to Subnet
	#
	debug "Associating Route Table with Subnet -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 associate-route-table --dry-run --subnet-id "${SUBNET_ID}" --route-table-id "${ROUTE_TABLE_ID}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Associating Route Table with Subnet -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 associate-route-table --subnet-id "${SUBNET_ID}" --route-table-id "${ROUTE_TABLE_ID}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Route Table associated with Subnet ${SUBNET_ID}"

else
	debug "Using existing Route Table associated with Subnet ${SUBNET_NAME}"
	# So we are using an existing Subnet of Subnet_NAME. Find its ID and set VPC_ID
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-route-tables --filters Name=association.subnet-id,Values="${SUBNET_ID}" --output text --query 'RouteTables[0].RouteTableId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	ROUTE_TABLE_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${ROUTE_TABLE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Route Table ID for route table for subnet ${SUBNET_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Found Route Table for Subnet with name ${SUBNET_NAME} and ID ${SUBNET_ID}"
fi



#
# With SUBNET_CIDR_BLOCK defined, now set JSON security group string
#
SG_JSON_INPUT="{ \
    \"DryRun\": false , \
    \"SourceSecurityGroupName\": \"\", \
    \"SourceSecurityGroupOwnerId\": \"\", \
    \"IpProtocol\": \"\", \
    \"CidrIp\": \"\", \
    \"IpPermissions\": [ \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 389, \
            \"ToPort\": 389, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"3.232.27.99/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3306, \
            \"ToPort\": 3306, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"3.232.27.99/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8080, \
            \"ToPort\": 8080, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"3.232.27.99/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 389, \
            \"ToPort\": 389, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"52.72.222.51/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3306, \
            \"ToPort\": 3306, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"52.72.222.51/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8080, \
            \"ToPort\": 8080, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"52.72.222.51/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 389, \
            \"ToPort\": 389, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"54.236.173.154/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3306, \
            \"ToPort\": 3306, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"54.236.173.154/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8080, \
            \"ToPort\": 8080, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"54.236.173.154/32\" \
                } \
            ] \
        },
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3306, \
            \"ToPort\": 3306, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"52.4.236.107/32\" \
                } \
            ] \
        },
		{ \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 80, \
            \"ToPort\": 80, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"0.0.0.0/0\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 88, \
            \"ToPort\": 88, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8080, \
            \"ToPort\": 8080, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8000, \
            \"ToPort\": 8000, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 0, \
            \"ToPort\": 65535, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SYSTECH_HOME_CIDR_BLOCK_2}\" \
                }, \
                { \
                    \"CidrIp\": \"${SYSTECH_HOME_CIDR_BLOCK_3}\" \
                }, \
                { \
                    \"CidrIp\": \"${SYSTECH_HOME_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 7771, \
            \"ToPort\": 7779, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 6379, \
            \"ToPort\": 6379, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 9001, \
            \"ToPort\": 9001, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 636, \
            \"ToPort\": 636, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 389, \
            \"ToPort\": 389, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3306, \
            \"ToPort\": 3306, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 5672, \
            \"ToPort\": 5675, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 15672, \
            \"ToPort\": 15672, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8880, \
            \"ToPort\": 8880, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3000, \
            \"ToPort\": 3000, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3001, \
            \"ToPort\": 3001, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 443, \
            \"ToPort\": 443, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"0.0.0.0/0\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 446, \
            \"ToPort\": 446, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"0.0.0.0/0\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 8081, \
            \"ToPort\": 8081, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 222, \
            \"ToPort\": 222, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        }, \
        { \
            \"IpProtocol\": \"tcp\", \
            \"FromPort\": 3268, \
            \"ToPort\": 3269, \
	    \"UserIdGroupPairs\" :[], \
            \"IpRanges\": [ \
                { \
                    \"CidrIp\": \"${SUBNET_CIDR_BLOCK}\" \
                } \
            ] \
        } \
    ] \
}"


########################################################################
#
# Create Security Group
#
########################################################################
SG_ID=""
if [ ${CONFIGURE_SG} -eq 1 ]
then
	debug "Configuring Security Group"

	debug "Security Group create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-security-group --dry-run --group-name "${SG_NAME}" --description "${SG_DESCRIPTION}" --vpc-id "${VPC_ID}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Security Group create -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-security-group --group-name "${SG_NAME}" --description "${SG_DESCRIPTION}" --vpc-id "${VPC_ID}" --output text --query 'GroupId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	SG_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${SG_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Security Group ID for created Security Group ${SG_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Security Group ${SG_NAME} created with ID ${SG_ID}"

	#
	# Add tags
	#
	debug "Tagging security group ${SG_NAME} -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${SG_ID}" --tags Key=Name,Value="${SG_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging security group ${SG_NAME} -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --resources "${SG_ID}" --tags Key=Name,Value="${SG_NAME}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	#
	# Now, configure the open ports
	#
	debug "Configuring open ports for security group ${SG_NAME} -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 authorize-security-group-ingress --dry-run --group-id "${SG_ID}" --cli-input-json "${SG_JSON_INPUT}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Configuring open ports for security group ${SG_NAME} -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 authorize-security-group-ingress  --group-id "${SG_ID}" --cli-input-json "${SG_JSON_INPUT}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
else
	# So we are using an existing SG of SG_NAME. Find its ID and set SG_ID
	debug "Using existing security group ${SG_NAME} -- obtaining ID"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-security-groups --filters Name=group-name,Values="${SG_NAME}" --output text --query 'SecurityGroups[0].GroupId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	SG_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${SG_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Security Group ID for Security Group ${SG_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Obtained ID ${SG_ID} for security group ${SG_NAME}"

	#
	# Now, configure the open ports
	#
	debug "Configuring open ports for security group ${SG_NAME} -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 authorize-security-group-ingress --dry-run --group-id "${SG_ID}" --cli-input-json "${SG_JSON_INPUT}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Configuring open ports for security group ${SG_NAME} -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 authorize-security-group-ingress  --group-id "${SG_ID}" --cli-input-json "${SG_JSON_INPUT}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo ${RESULT} | grep -q "InvalidPermission.Duplicate"
		if [ $? -eq 0 ]
		then
			echo -e \\n${FONT_BOLD}Benign error -- Security group exists and ports are already configured${FONT_NORMAL}\\n
			echo -e \\n${FONT_BOLD}Continuing, but check that port configuration is as desired!${FONT_NORMAL}\\n
		else
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
	fi
fi

########################################################################
#
# Create SQS
#
########################################################################

SQS_SIZE=3
PARSING_HIGH=${CLUSTER_NAME}_parsing_high.fifo
PARSING_MEDIUM=${CLUSTER_NAME}_parsing_medium
PRINTING_MEDIUM=${CLUSTER_NAME}_printing_medium
sqs_names=(${PARSING_HIGH} ${PARSING_MEDIUM} ${PRINTING_MEDIUM})

# Get the AWS Account number
AWS_ACCOUNT_NUMBER=`aws ${PROFILE_SPECIFIER} sts get-caller-identity --query Account --output text`

if [ ${CONFIGURE_SQS} -eq 1 -a ${UPDATE} -eq 0 ]
then
    CREATE_QUEUE_JSON=./create-queue.json
    CREATE_QUEUE_STRING=""
    SQS_SIZE=`expr ${SQS_SIZE} - 1`
    for sqs_num in $(eval echo  {0..${SQS_SIZE}})
    do
        QUEUE_NAME=`echo ${sqs_names[$sqs_num]}`
        # Condition for SQS Type
        if echo ${sqs_names[$sqs_num]} | grep -q "fifo"
        then
           debug "Creating Fifo type SQS"
           CREATE_QUEUE_STRING=`cat ${CREATE_QUEUE_JSON} | sed -e "s/REPLACE_FIFO_QUEUE_VALUE/true/"`
        else
           debug "Creating Standard type SQS"
           CREATE_QUEUE_STRING=`cat ${CREATE_QUEUE_JSON} | sed -e "/FifoQueue/d"`
        fi

        CREATE_QUEUE_STRING=`echo "${CREATE_QUEUE_STRING}" | sed -e "s/REPLACE_ACCOUNT_NAME/${AWS_ACCOUNT_NUMBER}/" | sed -e "s/REPLACE_QUEUE_NAME/${QUEUE_NAME}/"`
        RESULT=`aws ${PROFILE_SPECIFIER} sqs create-queue --queue-name ${QUEUE_NAME} --attributes "${CREATE_QUEUE_STRING}" --region us-east-1`
        debug "Created SQS has name ${QUEUE_NAME}"
        sleep 10
        sqs_num=`expr $sqs_num + 1`
    done
else
    echo "This is update or refresh job. Not require to create the SQS."
fi # END Create SQS

if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
then
	########################################################################
	#
	# Create Cluster
	#
	########################################################################
	CLUSTER_ID=""

	if [ ${CONFIGURE_CLUSTER} -eq 1 ]
	then
		debug "Configuring Cluster"

		debug "Cluster create -- actual run."
		RESULT=`aws ${PROFILE_SPECIFIER} ecs create-cluster --cluster-name "${CLUSTER_NAME}" --output text --query 'cluster.clusterArn' 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		CLUSTER_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${CLUSTER_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Cluster Arn for created Cluster ${CLUSTER_ID}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Created CLUSTER has name ${CLUSTER_NAME} and ID ${CLUSTER_ID}"

	else
		debug "Using existing CLUSTER of name ${CLUSTER_NAME}"
		# So we are using an existing CLUSTER of CLUSTER_NAME. Find its ID and set CLUSTER_ID
		RESULT=`aws ${PROFILE_SPECIFIER} ecs describe-clusters --cluster "${CLUSTER_NAME}" --output text --query 'clusters[0].clusterArn' 2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		CLUSTER_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${CLUSTER_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Cluster Arn for created Cluster ${CLUSTER_NAME}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Found CLUSTER with name ${CLUSTER_NAME} and ID ${CLUSTER_ID}"
	fi
	#   Step 2: Launch an Instance with the Amazon ECS AMI
	#   Step 3: List Container Instances
	#   Step 4: Describe your Container Instance
	#   Step 5: Register a Task Definition
	#   Step 6: List Task Definitions
	#   Step 7: Run a Task
	#   Step 8: List Tasks
	#   Step 9: Describe the Running Task

	########################################################################
	#
	# Create IAM Role for ECS2 Container instance
	#
	########################################################################
	ROLE_ID=""
	if [ ${CONFIGURE_ROLE} -eq 1 ]
	then
		debug "Configuring IAM Role for EC2 Container Instance"

		debug "IAM Role create -- actual run"
		#
		# NOTE -- DO NOT YET HAVE PROPER JSON FORMAT FOR ASSUME_ROLE_POLICY_DOCUMENT
		#
		RESULT=`aws ${PROFILE_SPECIFIER} iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document "${ASSUME_ROLE_POLICY_DOCUMENT_URL}"  --output text --query 'Role.RoleId' 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		ROLE_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${ROLE_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Role ID for created ROLE ${ROLE_NAME}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "IAM Role ${ROLE_NAME} created with ID ${ROLE_ID}"

		#
		# Now, attach the role policy
		#
		debug "Attaching role policy for  ${ROLE_NAME} -- actual run"
		RESULT=`aws ${PROFILE_SPECIFIER} iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${ROLE_ATTACH_POLICY_ARN}"  2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi

		#
		# And, finally, add the inline policy
		#
		debug "Adding in-line policy for  ${ROLE_NAME} -- actual run"
		RESULT=`aws ${PROFILE_SPECIFIER} iam put-role-policy --role-name "${ROLE_NAME}" --policy-name "${ROLE_INLINE_POLICY_NAME}"  --policy-document "${ROLE_INLINE_POLICY_DOCUMENT}"  2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
	else
		# So we are using an existing role of ROLE_NAME. Find its ID and set ROLE_ID
		debug "Using existing role ${ROLE_NAME} -- obtaining ID"
		RESULT=`aws ${PROFILE_SPECIFIER} iam get-role --role-name "${ROLE_NAME}" --output text --query 'Role.RoleId' 2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		ROLE_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${ROLE_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Role ID for ROLE ${ROLE_NAME}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Obtained ID ${ROLE_ID} for security group ${ROLE_NAME}"
	fi

	########################################################################
	#
	# Use the IAM Role to get instance profile information
	#
	########################################################################
	INSTANCE_PROFILE_NAME=""
	INSTANCE_PROFILE_ARN=""
	RESULT=`aws ${PROFILE_SPECIFIER} iam list-instance-profiles-for-role --role-name "${ROLE_NAME}" --output text --query 'InstanceProfiles[0].InstanceProfileName'`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	INSTANCE_PROFILE_NAME=`echo ${RESULT} | tr -d \\\\015`
	if [ "${INSTANCE_PROFILE_NAME}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Instance Profile for ROLE ${ROLE_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	INSTANCE_PROFILE_ARN=`aws ${PROFILE_SPECIFIER} iam list-instance-profiles-for-role --role-name ${ROLE_NAME} --output text --query 'InstanceProfiles[0].Arn' | tr -d \\\\015`
	if [ "${INSTANCE_PROFILE_ARN}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Instance Profile for ROLE ${ROLE_NAME}${FONT_NORMAL}\\n
		exit 1
	fi

fi # END EC2_ONLY_DEPLOYMENT

########################################################################
#
# Create Key-Pair for ECS2 Container instance
# Key pair only valid for region in which it is created. To use in other
# regions, see import-key-pair
#
########################################################################
if [ ${CONFIGURE_KEY_PAIR} -eq 1 ]
then
	debug "Configuring key pair for EC2 Container Instance"

	debug "Key-pair create -- dry run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-key-pair --dry-run --key-name "${KEY_PAIR_NAME}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Key-pair create -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-key-pair --key-name "${KEY_PAIR_NAME}" --query 'KeyMaterial' --output text `
	if [ $? -ne 0 ]
	then
		echo ${RESULT} | grep -q "InvalidKeyPair.Duplicate"
		if [ $? -eq 0 ]
		then
			echo -e \\n${FONT_BOLD}Benign error -- Key-pair exists${FONT_NORMAL}\\n
			echo -e \\n${FONT_BOLD}Continuing, but check that the private key is available!${FONT_NORMAL}\\n
		else
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
	else
		if [ "${RESULT}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Private Key for created key-pair ${KEY_PAIR_NAME}${FONT_NORMAL}\\n
			exit 1
		fi
		echo ${RESULT} > ${KEY_PAIR_FILE}
		debug "Key-pair ${KEY_PAIR_NAME} created"
	fi
else
	debug "Using existing key pair ${KEY_PAIR_NAME} for EC2 Container Instance"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-key-pairs --filters Name=key-name,Values="${KEY_PAIR_NAME}" --output text --query 'KeyPairs[0].KeyName' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	if [ "${RESULT}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain key-pair with name ${KEY_PAIR_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Obtained key-pair with name ${KEY_PAIR_NAME}"
fi


########################################################################
#
# Run EC2 Instances with Optimized AMI
# Create FrontEnd, BackEnd, and Support instances
# Allow FrontEnd and BackEnd to scale independently
# Support contains LDAP, Configurator, Redis (perhaps MySQL on prototype)
#
########################################################################
if [ ${CONFIGURE_INSTANCES} -eq 1 ]
then
	debug "Configuring EC2 Instances"
	if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
	then
		if [ ${ECS_CLEANUP_TIME} -ne 48 ]
		then
			USER_DATA_SCRIPT=./clusterIdScript.sh
			#USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" | base64 - `
			USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" `
			USER_DATA_STRING=`echo "${USER_DATA_STRING}" | sed -e "s/48/${ECS_CLEANUP_TIME}/"`
			echo "ECS cleanup duration set to:${ECS_CLEANUP_TIME} hours"
			MOUNT_DATA_SCRIPT=./lvmMountScript.sh
		else
			USER_DATA_SCRIPT=./clusterIdScript.sh
			#USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" | base64 - `
			USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" `
			MOUNT_DATA_SCRIPT=./lvmMountScript.sh
		fi
	else
 		USER_DATA_SCRIPT=./EC2OnlyStartScript.sh
		USER_DATA_STRING=`sed -e "s/EC2_RELEASE_TAG/${EC2_RELEASE_TAG}/g" ${USER_DATA_SCRIPT} `
		MOUNT_DATA_SCRIPT=./EC2OnlyMountScript.sh
	fi
	#FRONT_END_USER_DATA_STRING=${USER_DATA_STRING}
	#IAM_INSTANCE_PROFILE="Arn=${INSTANCE_PROFILE_ARN},Name=${INSTANCE_PROFILE_NAME}"
	# 2/1/16 -- Only need 1 of the 2 specified.  Go with name
	IAM_INSTANCE_PROFILE="Name=${INSTANCE_PROFILE_NAME}"
	#
	# Configure CloudFront
	#
	if [ ${ADD_TIER2_VOLUME} -eq 1 ]
	then
		# Create the volume, create the FRONT END SCRIPT
		debug "Creating volume for Tier 2 UniSearch"
		if [ "${TIER2_VOLUME_TYPE}" == "io1" ]
		then
			TIER2_VOLUME_IOPS_ARG=" --iops ${TIER2_VOLUME_IOPS}"
		else
			TIER2_VOLUME_IOPS_ARG=""
		fi
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-volume  --availability-zone ${INSTANCE_REGION} --region ${TIER2_VOLUME_REGION} --size ${TIER2_VOLUME_SIZE} --volume-type ${TIER2_VOLUME_TYPE} ${TIER2_VOLUME_IOPS_ARG} --output text --query 'VolumeId' 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		TIER2_VOLUME_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${TIER2_VOLUME_RESOURCE_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Tier 2 UniSearch Volume${FONT_NORMAL}\\n
			exit 1
		fi
		VGSIZE=$(echo ${TIER2_VOLUME_SIZE} | awk -e '{print $1 - 0.1}')
		FRONT_END_USER_DATA_STRING=`cat ${MOUNT_DATA_SCRIPT} | sed -e "s;{DEVICE};${TIER2_DEVICE_NAME};g" -e "s;{MOUNT};${TIER2_VOLUME_MOUNT};g" -e "s;{VGSIZE};${VGSIZE};g"`
		if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
		then
			FRONT_END_USER_DATA_STRING="${USER_DATA_STRING} ; ${FRONT_END_USER_DATA_STRING}"
		else
			# If doing an EC2-only deployment, set up the mounts BEFORE doing the image pulls, etc.
			FRONT_END_USER_DATA_STRING="${FRONT_END_USER_DATA_STRING} ; ${USER_DATA_STRING}"
		fi
	else
		FRONT_END_USER_DATA_STRING="${USER_DATA_STRING}"
	fi



	debug "Run Instances CloudFront -- dry run."
	BLOCK_DEVICE_MAPPING=`echo ${BLOCK_DEVICE_MAPPING_TEMPLATE} |sed -e "s/DOCKERVOL_SIZE/${FRONT_DOCKERVOL_SIZE}/" |sed -e "s/DOCKERVOL_TYPE/${EC2_VOLUME_TYPE}/"`
    RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --dry-run --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${FRONT_INSTANCE_TYPE}" --placement AvailabilityZone="${INSTANCE_REGION}",Tenancy="${INSTANCE_TENANCY}" --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${FRONT_END_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" --block-device-mapping "${BLOCK_DEVICE_MAPPING}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Run Instances CloudFront -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${FRONT_INSTANCE_TYPE}" --placement AvailabilityZone="${INSTANCE_REGION}",Tenancy="${INSTANCE_TENANCY}" --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${FRONT_END_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" --block-device-mapping "${BLOCK_DEVICE_MAPPING}" --output text --query 'Instances[0].InstanceId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	CLOUD_FRONT_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${CLOUD_FRONT_RESOURCE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Cloud Front End instance ${CLOUD_FRONT_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "CloudFront instance Running."

	#
	# Add tags for CloudFront
	#
	debug "Tagging CloudFront Instance -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${CLOUD_FRONT_RESOURCE_ID}" --tags Key=Name,Value="${CLOUD_FRONT_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging CloudFront Instance -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${CLOUD_FRONT_RESOURCE_ID}" --tags Key=Name,Value="${CLOUD_FRONT_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi


	#
	# Create Tier 2 UniSearch volume and add, if necessary
	#
	if [ ${ADD_TIER2_VOLUME} -eq 1 ]
	then
		debug "Waiting for front end to become available"
		aws ${PROFILE_SPECIFIER} ec2 wait instance-running --instance-ids ${CLOUD_FRONT_RESOURCE_ID}
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Instance ${CLOUD_FRONT_RESOURCE_ID} never attained RUNNING status.${FONT_NORMAL}\\n
			exit 1
		fi

		debug "Attaching Volume for Tier 2 Search for front end"
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 attach-volume --volume-id ${TIER2_VOLUME_RESOURCE_ID} --instance-id ${CLOUD_FRONT_RESOURCE_ID}  --device ${TIER2_DEVICE_NAME} 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		# The mount script should take care of formatting the volume and mounting it.
	fi




	#
	# Configure CloudBack
	#
	if [ ${ADD_INCORTA_VOLUME} -eq 1 ]
	then
		# 10/5/17 -- Moving Incorta to the Back End, so use a script on the BACK END
		# Create the volume, create the FRONT END SCRIPT
		debug "Creating volume for Incorta"
		if [ "${INCORTA_VOLUME_TYPE}" == "io1" ]
		then
			INCORTA_VOLUME_IOPS_ARG=" --iops ${INCORTA_VOLUME_IOPS}"
		else
			INCORTA_VOLUME_IOPS_ARG=""
		fi
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-volume  --availability-zone ${INSTANCE_REGION} --region ${INCORTA_VOLUME_REGION} --size ${INCORTA_VOLUME_SIZE} --volume-type ${INCORTA_VOLUME_TYPE} ${INCORTA_VOLUME_IOPS_ARG} --output text --query 'VolumeId' 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		INCORTA_VOLUME_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${INCORTA_VOLUME_RESOURCE_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Incorta Volume${FONT_NORMAL}\\n
			exit 1
		fi
		VGSIZE=$(echo ${INCORTA_VOLUME_SIZE} | awk -e '{print $1 - 0.1}')
		BACK_END_USER_DATA_STRING=`cat ${MOUNT_DATA_SCRIPT} | sed -e "s;{DEVICE};${INCORTA_DEVICE_NAME};g" -e "s;{MOUNT};${INCORTA_VOLUME_MOUNT};g" -e "s;{VGSIZE};${VGSIZE};g"`
		if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
		then
			BACK_END_USER_DATA_STRING="${USER_DATA_STRING} ; ${BACK_END_USER_DATA_STRING}"
		else
			# If doing an EC2-only deployment, set up the mounts BEFORE doing the image pulls, etc.
			BACK_END_USER_DATA_STRING="${BACK_END_USER_DATA_STRING} ; ${USER_DATA_STRING}"
		fi
	else
		BACK_END_USER_DATA_STRING="${USER_DATA_STRING}"
	fi
	debug "Run Instances CloudBack -- dry run."
	BLOCK_DEVICE_MAPPING=`echo ${BLOCK_DEVICE_MAPPING_TEMPLATE} |sed -e "s/DOCKERVOL_SIZE/${BACK_DOCKERVOL_SIZE}/" |sed -e "s/DOCKERVOL_TYPE/${EC2_VOLUME_TYPE}/"`
    RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --dry-run --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${BACK_INSTANCE_TYPE}" --placement "AvailabilityZone=${INSTANCE_REGION},Tenancy=${INSTANCE_TENANCY}" --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${BACK_END_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" --block-device-mapping "${BLOCK_DEVICE_MAPPING}" 2>&1`
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	# It would have worked, so do it for real
	debug "Run Instances CloudBack -- actual run."
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${BACK_INSTANCE_TYPE}" --placement "AvailabilityZone=${INSTANCE_REGION},Tenancy=${INSTANCE_TENANCY}" --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${BACK_END_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" --block-device-mapping "${BLOCK_DEVICE_MAPPING}" --output text --query 'Instances[0].InstanceId' 2>&1`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	CLOUD_BACK_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${CLOUD_BACK_RESOURCE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Cloud Back End instance ${CLOUD_BACK_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "CloudBack instance Running."

	#
	# Add tags for CloudBack
	#
	debug "Tagging CloudBack Instance -- dry run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${CLOUD_BACK_RESOURCE_ID}" --tags Key=Name,Value="${CLOUD_BACK_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging CloudBack Instance -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${CLOUD_BACK_RESOURCE_ID}" --tags Key=Name,Value="${CLOUD_BACK_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	#
	# Create Incorta volume and add, if necessary
	#
	if [ ${ADD_INCORTA_VOLUME} -eq 1 ]
	then
		debug "Waiting for back end to become available"
		aws ${PROFILE_SPECIFIER} ec2 wait instance-running --instance-ids ${CLOUD_BACK_RESOURCE_ID}
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Instance ${CLOUD_BACK_RESOURCE_ID} never attained RUNNING status.${FONT_NORMAL}\\n
			exit 1
		fi

		debug "Attaching Volume for Incorta for back end"
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 attach-volume --volume-id ${INCORTA_VOLUME_RESOURCE_ID} --instance-id ${CLOUD_BACK_RESOURCE_ID}  --device ${INCORTA_DEVICE_NAME} 2>&1`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		# The mount script should take care of formatting the volume and mounting it.
	fi

	if [ ${FIX} -eq 0 ]
	then
		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			MOUNT_DATA_SCRIPT=./lvmMountScript.sh
			if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
			then
				if [ ${ECS_CLEANUP_TIME} -ne 48 ]
				then
					USER_DATA_SCRIPT=./clusterIdScript.sh
					#USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" | base64 - `
					USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" `
					USER_DATA_STRING=`echo "${USER_DATA_STRING}" | sed -e "s/48/${ECS_CLEANUP_TIME}/"`
					echo "ECS cleanup duration set to:${ECS_CLEANUP_TIME} hours"
					MOUNT_DATA_SCRIPT=./lvmMountScript.sh
				else
					USER_DATA_SCRIPT=./clusterIdScript.sh
					#USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" | base64 - `
					USER_DATA_STRING=`cat ${USER_DATA_SCRIPT} | sed -e "s/REPLACE_ME_WITH_CLUSTER_NAME/${CLUSTER_NAME}/" `
					MOUNT_DATA_SCRIPT=./lvmMountScript.sh
				fi
			else
 				USER_DATA_SCRIPT=./EC2OnlyStartScript.sh
				USER_DATA_STRING=`sed -e "s/EC2_RELEASE_TAG/${EC2_RELEASE_TAG}/g" ${USER_DATA_SCRIPT} `
			fi
			if [ ${ADD_UNISEARCH_VOLUME} -eq 1 ]
			then
				# Create the volume, create the UNISEARCH SCRIPT
				debug "Creating volume for UNISEARCH"
				if [ "${UNISEARCH_VOLUME_TYPE}" == "io1" ]
				then
					UNISEARCH_VOLUME_IOPS_ARG=" --iops ${UNISEARCH_VOLUME_IOPS}"
				else
					UNISEARCH_VOLUME_IOPS_ARG=""
				fi
				RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-volume  --availability-zone ${INSTANCE_REGION} --region ${UNISEARCH_VOLUME_REGION} --size ${UNISEARCH_VOLUME_SIZE} --volume-type ${UNISEARCH_VOLUME_TYPE} ${UNISEARCH_VOLUME_IOPS_ARG} --output text --query 'VolumeId' 2>&1`
				if [ $? -ne 0 ]
				then
					echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
					exit 1
				fi
				UNISEARCH_VOLUME_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
				if [ "${UNISEARCH_VOLUME_RESOURCE_ID}" == "None" ]
				then
					echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Incorta Volume${FONT_NORMAL}\\n
					exit 1
				fi
				VGSIZE=$(echo ${UNISEARCH_VOLUME_SIZE} | awk -e '{print $1 - 0.1}')
				UNISEARCH_USER_DATA_STRING=`cat ${MOUNT_DATA_SCRIPT} | sed -e "s;{DEVICE};${UNISEARCH_DEVICE_NAME};g" -e "s;{MOUNT};${UNISEARCH_VOLUME_MOUNT};g" -e "s;{VGSIZE};${VGSIZE};g"`
				UNISEARCH_USER_DATA_STRING="${USER_DATA_STRING};${UNISEARCH_USER_DATA_STRING}"
			else
				UNISEARCH_USER_DATA_STRING=${USER_DATA_STRING}
			fi
			#
			# Configure Search
			#
			debug "Run Instances Search -- dry run."
			RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --dry-run --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${SEARCH_INSTANCE_TYPE}" --placement "AvailabilityZone=${INSTANCE_REGION},Tenancy=${INSTANCE_TENANCY}" --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${UNISEARCH_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" 2>&1`
			SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi
			# It would have worked, so do it for real
			debug "Run Instances Search -- actual run."
			RESULT=`aws ${PROFILE_SPECIFIER} ec2 run-instances --image-id "${ECS_AMI_ID}" --key-name "${KEY_PAIR_NAME}" --security-group-ids "${SG_ID}" --instance-type "${SEARCH_INSTANCE_TYPE}" --placement "AvailabilityZone=${INSTANCE_REGION},Tenancy=${INSTANCE_TENANCY}"  --subnet-id "${SUBNET_ID}" --associate-public-ip-address --user-data "${UNISEARCH_USER_DATA_STRING}" --count 1 --iam-instance-profile "${IAM_INSTANCE_PROFILE}" --output text --query 'Instances[0].InstanceId' 2>&1`
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi
			SEARCH_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
			if [ "${SEARCH_RESOURCE_ID}" == "None" ]
			then
				echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created Search Instance ${SEARCH_ID}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Search instance Running."

			#
			# Add tags for Search
			#
			debug "Tagging Search Instance -- dry run"
			RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags --dry-run --resources "${SEARCH_RESOURCE_ID}" --tags Key=Name,Value="${SEARCH_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
			SUCCEEDED=`echo $RESULT | grep "DryRunOperation"`
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Tagging Search Instance -- actual run"
				RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${SEARCH_RESOURCE_ID}" --tags Key=Name,Value="${SEARCH_ID}" Key=Creator,Value="${TAG_CREATOR}" Key=Date,Value="${TAG_DATE}" Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" 2>&1 `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi

			#
			# Attach the Unisearch volume, if necessary
			#
			if [ ${ADD_UNISEARCH_VOLUME} -eq 1 ]
			then
				debug "Waiting for front end to become available"
				aws ${PROFILE_SPECIFIER} ec2 wait instance-running --instance-ids ${SEARCH_RESOURCE_ID}
				if [ $? -ne 0 ]
				then
					echo -e \\n${FONT_BOLD}Instance ${SEARCH_RESOURCE_ID} never attained RUNNING status.${FONT_NORMAL}\\n
					exit 1
				fi

				debug "Attaching Volume for Incorta for front end"
				RESULT=`aws ${PROFILE_SPECIFIER} ec2 attach-volume --volume-id ${UNISEARCH_VOLUME_RESOURCE_ID} --instance-id ${SEARCH_RESOURCE_ID}  --device ${INCORTA_DEVICE_NAME} 2>&1`
				if [ $? -ne 0 ]
				then
					echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
					exit 1
				fi
				# The mount script should take care of formatting the volume and mounting it.
			fi
		fi
       	else
		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			# Search
			debug "Finding resource ID for existing instance ${SEARCH_ID}"
			RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --filters Name=tag:Name,Values="${SEARCH_ID}" Name=instance-state-name,Values=running --output text --query 'Reservations[0].Instances[0].InstanceId' 2>&1 `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi
			SEARCH_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
			if [ "${SEARCH_RESOURCE_ID}" == "None" ]
			then
				echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created search instance ${SEARCH_ID}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Obtained Resource ID ${SEARCH_RESOURCE_ID} for instance with name ${SEARCH_ID}"
		fi

	fi
else
	# Need to find instance resource IDs

	# Cloud Front
	debug "Finding resource ID for existing instance ${CLOUD_FRONT_ID}"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --filters Name=tag:Name,Values="${CLOUD_FRONT_ID}" Name=instance-state-name,Values=running --output text --query 'Reservations[0].Instances[0].InstanceId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	CLOUD_FRONT_RESOURCE_ID=`echo ${RESULT}| tr -d \\\\015`
	if [ "${CLOUD_FRONT_RESOURCE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Resource ID for Cloud Front End instance ${CLOUD_FRONT_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Obtained Resource ID ${CLOUD_FRONT_RESOURCE_ID} for instance with name ${CLOUD_FRONT_ID}"

	# Cloud Back
	debug "Finding resource ID for existing instance ${CLOUD_BACK_ID}"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --filters Name=tag:Name,Values="${CLOUD_BACK_ID}" Name=instance-state-name,Values=running --output text --query 'Reservations[0].Instances[0].InstanceId' 2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	CLOUD_BACK_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
	if [ "${CLOUD_BACK_RESOURCE_ID}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain Resource ID for Cloud Back End instance ${CLOUD_BACK_ID}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Obtained Resource ID ${CLOUD_BACK_RESOURCE_ID} for instance with name ${CLOUD_BACK_ID}"

	if [ ${DEPLOY_UNISEARCH} -ne 0 ]
	then
		# Search
		debug "Finding resource ID for existing instance ${SEARCH_ID}"
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --filters Name=tag:Name,Values="${SEARCH_ID}" Name=instance-state-name,Values=running --output text --query 'Reservations[0].Instances[0].InstanceId' 2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		SEARCH_RESOURCE_ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${SEARCH_RESOURCE_ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain Resource ID for created search instance ${SEARCH_ID}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Obtained Resource ID ${SEARCH_RESOURCE_ID} for instance with name ${SEARCH_ID}"
	fi
fi

if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
then
	########################################################################
	#
	# Create and Register Task Definitions
	#
	########################################################################
	if [ ${CONFIGURE_TASK_DEFINITION} -eq 1 ]
	then
		debug "Configuring Task Definitions"

		debug "Register Front End task definition -- actual run"
		RESULT=`aws ${PROFILE_SPECIFIER} ecs register-task-definition --family "${FRONT_END_TASK_DEFINITION_NAME}" --cli-input-json "${FRONT_END_CONTAINER_DEFINITION_FILE}"  2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Task Definition ${FRONT_END_TASK_DEFINITION_NAME} created."

		debug "Register Back End task definition -- actual run"
		RESULT=`aws ${PROFILE_SPECIFIER} ecs register-task-definition --family "${BACK_END_TASK_DEFINITION_NAME}" --cli-input-json "${BACK_END_CONTAINER_DEFINITION_FILE}"  2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		debug "Task Definition ${BACK_END_TASK_DEFINITION_NAME} created."

		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			debug "Register Search task definition -- actual run"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs register-task-definition --family "${SEARCH_TASK_DEFINITION_NAME}" --cli-input-json "${SEARCH_CONTAINER_DEFINITION_FILE}"  2>&1 `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Task Definition ${SEARCH_TASK_DEFINITION_NAME} created."
		fi

	else
		debug "Searching for Front End Task Definition ${FRONT_END_TASK_DEFINITION_NAME}"
		RESULT=`aws ${PROFILE_SPECIFIER} ecs list-task-definition-families --family-prefix "${FRONT_END_TASK_DEFINITION_NAME}" | grep \"${FRONT_END_TASK_DEFINITION_NAME}\" `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Failed to find task definition ${FRONT_END_TASK_DEFINITION_NAME}${FONT_NORMAL}\\n
			exit 1
		fi

		debug "Searching for Back End Task Definition ${BACK_END_TASK_DEFINITION_NAME}"
		RESULT=`aws ${PROFILE_SPECIFIER} ecs list-task-definition-families --family-prefix "${BACK_END_TASK_DEFINITION_NAME}" | grep \"${BACK_END_TASK_DEFINITION_NAME}\" `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Failed to find task definition ${BACK_END_TASK_DEFINITION_NAME}${FONT_NORMAL}\\n
			exit 1
		fi

		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			debug "Searching for Search Task Definition ${SEARCH_TASK_DEFINITION_NAME}"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs list-task-definition-families --family-prefix "${SEARCH_TASK_DEFINITION_NAME}" | grep \"${SEARCH_TASK_DEFINITION_NAME}\" `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to find task definition ${SEARCH_TASK_DEFINITION_NAME}${FONT_NORMAL}\\n
				exit 1
			fi
		fi
	fi

fi # End EC2_ONLY_DEPLOYMENT
########################################################################
#
# Assemble overrides -- IP addresses for Redis, MySql, LDAP, and Cloud Back
# LDAP, Redis, and MySQL are on the same ECS container instance, cloud back
# is on a separate container instance.
#
########################################################################
debug "Assembling overrides"

### BOBP 12/12/19 -- Getting rid of the support instance, so we need to decide what instance will host LDAP
IP=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --instance-ids ${CLOUD_FRONT_RESOURCE_ID} --output text --query "Reservations[0].Instances[0].PrivateIpAddress" `
CLOUD_LDAP_IP=`echo ${IP} | tr -d \\\\015`
if [ "${CLOUD_LDAP_IP}" == "None" ]
then
	echo -e \\n${FONT_BOLD}Could not obtain IP address for created support instance.${FONT_NORMAL}\\n
	exit 1
fi
CLOUD_MYSQL_IP=${CLOUD_LDAP_IP}
CLOUD_REDIS_IP=${CLOUD_LDAP_IP}

if [ ${DEPLOY_UNISEARCH} -ne 0 ]
then
	IP=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --instance-ids ${SEARCH_RESOURCE_ID} --output text --query "Reservations[0].Instances[0].PrivateIpAddress" `
CLOUD_UNISEARCH_IP=`echo ${IP} | tr -d \\\\015`
	if [ "${CLOUD_UNISEARCH_IP}" == "None" ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain IP address for created search instance.${FONT_NORMAL}\\n
		exit 1
	fi
	UNISEARCH_MYSQL_IP=${CLOUD_UNISEARCH_IP}
else
	UNISEARCH_MYSQL_IP="127.0.0.1"
	CLOUD_UNISEARCH_IP="127.0.0.1"
fi

IP=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --instance-ids ${CLOUD_BACK_RESOURCE_ID} --output text --query "Reservations[0].Instances[0].PrivateIpAddress" `
CLOUD_BACK_IP=`echo ${IP} | tr -d \\\\015`
if [ "${CLOUD_BACK_IP}" == "None" ]
then
	echo -e \\n${FONT_BOLD}Could not obtain IP address for created cloud back end instance.${FONT_NORMAL}\\n
	exit 1
fi

IP=`aws ${PROFILE_SPECIFIER} ec2 describe-instances --instance-ids ${CLOUD_FRONT_RESOURCE_ID} --output text --query "Reservations[0].Instances[0].PrivateIpAddress" `
CLOUD_FRONT_IP=`echo ${IP} | tr -d \\\\015`
if [ "${CLOUD_FRONT_IP}" == "None" ]
then
	echo -e \\n${FONT_BOLD}Could not obtain IP address for created cloud front end instance.${FONT_NORMAL}\\n
	exit 1
fi

CLOUD_UNISECURE_IP=${CLOUD_FRONT_IP}
CLOUD_FINGERPRINT_IP=${CLOUD_FRONT_IP}

if [ -z "${CLOUD_UNISPHERE_IP}" ]
then
	CLOUD_UNISPHERE_IP="${CLOUD_UNISECURE_IP}"
fi

# Queue name overrides
SQS_OVERRIDES="{ \"name\": \"PARSING_HIGH\",\
		  \"value\": \"${PARSING_HIGH}\" },\
		{ \"name\": \"PARSING_MEDIUM\",\
		  \"value\": \"${PARSING_MEDIUM}\"},\
		{ \"name\": \"PRINTING_MEDIUM\",\
		  \"value\": \"${PRINTING_MEDIUM}\" }"

IP_ADDRESS_OVERRIDES="{ \"name\": \"CLOUD_BACK_IP\",\
		  \"value\": \"${CLOUD_BACK_IP}\" },\
		{ \"name\": \"CLOUD_LDAP_IP\",\
		  \"value\": \"${CLOUD_LDAP_IP}\"},\
		{ \"name\": \"CLOUD_MYSQL_IP\",\
		  \"value\": \"${CLOUD_MYSQL_IP}\"},\
		{ \"name\": \"CLOUD_REDIS_IP\",\
		  \"value\": \"${CLOUD_REDIS_IP}\"},\
		{ \"name\": \"CLOUD_UNISEARCH_IP\",\
		  \"value\": \"${CLOUD_UNISEARCH_IP}\"},\
		{ \"name\": \"UNISEARCH_MYSQL_IP\",\
		  \"value\": \"${UNISEARCH_MYSQL_IP}\"},\
		{ \"name\": \"CLOUD_FRONT_IP\",\
		  \"value\": \"${CLOUD_FRONT_IP}\" },\
		{ \"name\": \"CLOUD_UNISPHERE_IP\",\
		  \"value\": \"${CLOUD_UNISPHERE_IP}\" },\
		{ \"name\": \"CLUSTER_NAME\",\
		  \"value\": \"${CLUSTER_NAME}\" },\
		{ \"name\": \"CLOUD_UNISECURE_IP\",\
		  \"value\": \"${CLOUD_UNISECURE_IP}\" },
		{ \"name\": \"CLOUD_FINGERPRINT_IP\",\
		  \"value\": \"${CLOUD_FINGERPRINT_IP}\" }"

COGNITO_URL_OVERRIDES="{ \"name\": \"NotificationEventAWSCognitoURL\",\
		  \"value\": \"${COGNI_URL}\" },\
		  { \"name\": \"NotificationEventAWSLamdaURL\",\
		  \"value\": \"${LAMDA_URL}\"},\
		  { \"name\": \"ALERT_SUBSCRIPTION_SERVICE_BASE_URL\",\
		  \"value\": \"${ALERT_URL}\"},\
		  { \"name\": \"NotificationEventAWSCognitoUserName\",\
		  \"value\": \"${COG_USER}\"},\
		  { \"name\": \"NotificationEventAWSCognitoPassword\",\
		  \"value\": \"${COG_PASS}\"},\
		  { \"name\": \"NotificationEventAWSCognitoClientId\",\
		  \"value\": \"${COG_CLIENT}\"}"

COGNITO_URL_TAGS" Key=NotificationEventAWSCognitoURL,Value=${COGNI_URL} \
	Key=NotificationEventAWSLamdaURL,Value=${LAMDA_URL} \
	Key=ALERT_SUBSCRIPTION_SERVICE_BASE_URL,Value=${ALERT_URL} \
	Key=NotificationEventAWSCognitoUserName,Value=${COG_USER} \
	Key=NotificationEventAWSCognitoPassword,Value=${COG_PASS} \
	Key=NotificationEventAWSCognitoClientId,Value=${COG_CLIENT}"

IP_ADDRESS_TAGS=" Key=CLOUD_BACK_IP,Value=${CLOUD_BACK_IP} \
	Key=CLOUD_LDAP_IP,Value=${CLOUD_LDAP_IP} \
	Key=CLOUD_MYSQL_IP,Value=${CLOUD_MYSQL_IP} \
	Key=CLOUD_REDIS_IP,Value=${CLOUD_REDIS_IP} \
	Key=CLOUD_UNISEARCH_IP,Value=${CLOUD_UNISEARCH_IP} \
	Key=UNISEARCH_MYSQL_IP,Value=${UNISEARCH_MYSQL_IP} \
	Key=CLOUD_FRONT_IP,Value=${CLOUD_FRONT_IP} \
	Key=CLOUD_UNISPHERE_IP,Value=${CLOUD_UNISPHERE_IP} \
	Key=CLUSTER_NAME,Value=${CLUSTER_NAME} \
	Key=CLOUD_UNISECURE_IP,Value=${CLOUD_UNISECURE_IP} \
	Key=CLOUD_FINGERPRINT_IP,Value=${CLOUD_FINGERPRINT_IP} "

AWS_S3_OVERRIDES="{ \"name\": \"AWS_USE_S3\",\
		  \"value\": \"${AWS_USE_S3}\" },\
		{ \"name\": \"PRODUCTION_BUILD\",\
		  \"value\": \"${PRODUCTION_BUILD}\"},
		{ \"name\": \"S3_FP_WRITE\", \
		  \"value\": \"${S3_FP_WRITE}\"},"

AWS_S3_TAGS=" Key=AWS_USE_S3,Value=${AWS_USE_S3} \
	Key=PRODUCTION_BUILD,Value=${PRODUCTION_BUILD} "

if [ -n "${S3_KEYS}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"S3_KEYS\",\
		  \"value\": \"${S3_KEYS}\"}, "
	REVISED_S3_KEYS=`echo ${S3_KEYS} |sed -e 's/[ 	]*//g' -e 's/:/\\\\:/g' -e 's/{/\\\\{/g' -e 's/}/\\\\}/g'`
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=S3_KEYS,Value=\"${REVISED_S3_KEYS}\" "
fi
if [ -n "${S3_ALL_REGIONS}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"S3_ALL_REGIONS\",\
		  \"value\": \"${S3_ALL_REGIONS}\"}, "
	REVISED_S3_ALL_REGIONS=`echo ${S3_ALL_REGIONS} | sed -e 's/[ 	]*//g'`
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=S3_ALL_REGIONS,Value=\"${REVISED_S3_ALL_REGIONS}\" "
fi
if [ -n "${S3_ROOT}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"S3_ROOT\",\
		  \"value\": \"${S3_ROOT}\"}, "
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=S3_ROOT,Value=${S3_ROOT} "
fi
if [ -n "${AWS_STORAGE_BUCKET_NAME}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"AWS_STORAGE_BUCKET_NAME\",\
		  \"value\": \"${AWS_STORAGE_BUCKET_NAME}\"}, "
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=AWS_STORAGE_BUCKET_NAME,Value=${AWS_STORAGE_BUCKET_NAME} "
fi
if [ -n "${AWS_CLOUDFRONT_URL}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"AWS_CLOUDFRONT_URL\",\
		  \"value\": \"${AWS_CLOUDFRONT_URL}\"}, "
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=AWS_CLOUDFRONT_URL,Value=${AWS_CLOUDFRONT_URL} "
fi
if [ -n "${AWS_CLOUDFRONT_KEYPAIR_ID}" ]
then
	AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
		{ \"name\": \"AWS_CLOUDFRONT_KEYPAIR_ID\",\
		  \"value\": \"${AWS_CLOUDFRONT_KEYPAIR_ID}\"}, "
	AWS_S3_TAGS="${AWS_S3_TAGS} Key=AWS_CLOUDFRONT_KEYPAIR_ID,Value=${AWS_CLOUDFRONT_KEYPAIR_ID} "
fi

AWS_S3_OVERRIDES="${AWS_S3_OVERRIDES} \
	{ \"name\": \"S3_DEFAULT_REGION\",\
	  \"value\": \"${S3_DEFAULT_REGION}\"}"
AWS_S3_TAGS="${AWS_S3_TAGS} Key=S3_DEFAULT_REGION,Value=${S3_DEFAULT_REGION} "


UNICLOUDFILE_OVERRIDES="${UNICLOUDFILE_OVERRIDES} \
	{ \"name\": \"UNIFILE_HOST\",\
	  \"value\": \"${UNIFILE_HOST}\"}, \
	{ \"name\": \"UNICLOUD_HOST\",\
	  \"value\": \"${UNICLOUD_HOST}\"}"

if [ -n "${UNIFILE_HOST}" ]
then
	UNICLOUDFILE_TAGS="${UNICLOUDFILE_TAGS} Key=UNIFILE_HOST,Value=${UNIFILE_HOST} "
fi
if [ -n "${UNICLOUD_HOST}" ]
then
	UNICLOUDFILE_TAGS="${UNICLOUDFILE_TAGS} Key=UNICLOUD_HOST,Value=${UNICLOUD_HOST} "
fi

CLOUD_FRONT_OVERRIDES="{ \"containerOverrides\":[ {\
		\"name\": \"cloud-front\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${SQS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES} \
		] }, { \
		\"name\": \"unisecure\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES}, \
		${COGNITO_URL_OVERRIDES} \
		] }, { \
		\"name\": \"cloud-fingerprint\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES} \
		] }] }"
if [ "${RELEASE_TAG}" -ge "8100" ]
then
    CLOUD_BACK_OVERRIDES="{ \"containerOverrides\":[ {\
		\"name\": \"cloud-back\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${SQS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} , \
		${UNICLOUDFILE_OVERRIDES} \
		] }, { \
		\"name\": \"cloud-secutil\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES} \
		  ] } ] }"
elif [ "${RELEASE_TAG}" -ge "850" && "${RELEASE_TAG}" -lt "8100" ]
then
	CLOUD_BACK_OVERRIDES="{ \"containerOverrides\":[ {\
		\"name\": \"cloud-back\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${SQS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} , \
		${UNICLOUDFILE_OVERRIDES} \
		] }, { \
    	\"name\": \"incorta\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES} \
		] }, { \
		\"name\": \"cloud-secutil\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} ,\
		${UNICLOUDFILE_OVERRIDES} \
		  ] } ] }"
else
	CLOUD_BACK_OVERRIDES="{ \"containerOverrides\":[ {\
		\"name\": \"cloud-back\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${SQS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} , \
		${UNICLOUDFILE_OVERRIDES} \
		  ] } ] }"
fi

UNISEARCH_WEB_OVERRIDES="{ \"containerOverrides\":[ {\
		\"name\": \"cloud-unisearch\",\
		\"environment\":[ \
		${IP_ADDRESS_OVERRIDES}, \
		${AWS_S3_OVERRIDES} , \
		${UNICLOUDFILE_OVERRIDES} \
		  ] } ] }"

#
# Set overrides on Pure EC2 deployments
#
if [ ${EC2_ONLY_DEPLOYMENT} -ne 0 ]
then
	debug "Tagging Cloud-Front Instance -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${CLOUD_FRONT_RESOURCE_ID}" --tags Key=FUNCTION,Value=cloud-front Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" ${AWS_S3_TAGS} ${IP_ADDRESS_TAGS} ${UNICLOUDFILE_TAGS}  2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Tagging Cloud-Back Instance -- actual run"
	RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${CLOUD_BACK_RESOURCE_ID}" --tags Key=FUNCTION,Value=cloud-back Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" ${AWS_S3_TAGS} ${IP_ADDRESS_TAGS} ${UNICLOUDFILE_TAGS}  2>&1 `
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi

	if [ ${DEPLOY_UNISEARCH} -ne 0 ]
	then
		debug "Tagging Search Instance -- actual run"
		RESULT=`aws ${PROFILE_SPECIFIER} ec2 create-tags  --resources "${SEARCH_RESOURCE_ID}" --tags Key=FUNCTION,Value=unisearch Key=Owner,Value="${TAG_OWNER}" Key=RetirementDate,Value="${TAG_RETIREMENT_DATE}" Key=Description,Value="${TAG_DESCRIPTION}" ${AWS_S3_TAGS} ${IP_ADDRESS_TAGS} ${UNICLOUDFILE_TAGS}  2>&1 `
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
	fi
fi


########################################################################
#
# The aws ecs start-task command take a container instance ID or ARN
# THIS IS NOT THE SAME AS AN INSTANCE ID.
# There isn't really a nice way to get the Container Instance Id from an
# Instance Id.  The best we can do is to list all Container Instance Ids
# in a cluster, then iterate down the list, describing the container instances
# and comparing the ec2InstanceId field to our EC2 Instance Id
#
########################################################################
if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
then

	debug "Obtaining List of Container Instance Arns for Cluster ${CLUSTER_NAME}"
	RESULT=`aws ${PROFILE_SPECIFIER} ecs list-container-instances --cluster "${CLUSTER_NAME}" --output text --query 'containerInstanceArns'`
	if [ $? -ne 0 ]
	then
		echo -e \\n${FONT_BOLD}Could not obtain container instance ARN list for cluster ${CLUSTER_NAME}: ${RESULT}${FONT_NORMAL}\\n
		exit 1
	fi
	ARN_LIST=`echo ${RESULT} | tr -d \\\\015`
	if [ ${CONFIGURE_INSTANCES} -eq 1 ]
	then
		# Instances were just configured.  Wait 3 minutes for them to register
		NOW=`date`
		debug "Waiting 3 minutes from ${NOW} to allow instances to register"
		sleep 180
		RESULT=`aws ${PROFILE_SPECIFIER} ecs list-container-instances --cluster "${CLUSTER_NAME}" --output text --query 'containerInstanceArns'`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain container instance ARN list for cluster ${CLUSTER_NAME}: ${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		ARN_LIST=`echo ${RESULT} | tr -d \\\\015`
	fi
	if [ "${ARN_LIST}" == "None" -o -z "${ARN_LIST}" ]
	then
		echo -e \\n${FONT_BOLD}Found empty container instance ARN list for cluster ${CLUSTER_NAME}${FONT_NORMAL}\\n
		exit 1
	fi
	debug "Obtained container instance ARN list. Iterating over list."

	for i in ${ARN_LIST}
	do
		RESULT=`aws ${PROFILE_SPECIFIER} ecs describe-container-instances --cluster "${CLUSTER_NAME}" --container-instances "$i" --output text --query 'containerInstances[0].ec2InstanceId'`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain EC2 Instance ID for ARN $i: ${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		EC2ID=`echo ${RESULT} | tr -d \\\\015`
		if [ "${EC2ID}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}Found empty EC2 Instance Id for Container Instance $i${FONT_NORMAL}\\n
			exit 1
		fi
		# Now compare with known IDs and set accordingly.
		if [ "${EC2ID}" == "${CLOUD_FRONT_RESOURCE_ID}" ]
		then
			CLOUD_FRONT_CONTAINER_INSTANCE_ARN=$i
		elif [ "${EC2ID}" == "${CLOUD_BACK_RESOURCE_ID}" ]
		then
			CLOUD_BACK_CONTAINER_INSTANCE_ARN=$i
		elif [ "${EC2ID}" == "${SEARCH_RESOURCE_ID}" ]
		then
			SEARCH_CONTAINER_INSTANCE_ARN=$i
		fi
	done

	debug "Checking that all container ARNs have been found"
	if [ -z "${CLOUD_FRONT_CONTAINER_INSTANCE_ARN}" ]
	then
		echo -e \\n${FONT_BOLD}Found empty container instance ARN list for Cloud Front container instance${FONT_NORMAL}\\n
		exit 1
	elif [ -z "${CLOUD_BACK_CONTAINER_INSTANCE_ARN}" ]
	then
		echo -e \\n${FONT_BOLD}Found empty container instance ARN list for Cloud Back container instance${FONT_NORMAL}\\n
		exit 1
	elif [ ${DEPLOY_UNISEARCH} -eq 1 -a -z "${SEARCH_CONTAINER_INSTANCE_ARN}" ]
	then
		echo -e \\n${FONT_BOLD}Found empty container instance ARN list for Search container instance${FONT_NORMAL}\\n
		exit 1
	fi
	debug "All Container ARNs have been found and are valid"


	########################################################################
	#
	# Stop Running Tasks?? (Are we doing an Update?)
	#
	########################################################################
	if [ ${UPDATE} -eq 1 -o ${FRONTEND_UPDATE} -eq 1 -o ${BACKEND_UPDATE} -eq 1 ]
	then
		# Do not stop support task!

		FRONT_END_TASK_DEF_ARN=""
		# Get task ARNs for front and back end
		FETDN=""
		if [ ${RELEASE_UPDATE} -eq 1 ]
		then
			FETDN=${OLD_FRONT_END_TASK_DEFINITION_NAME}
		else
			FETDN=${FRONT_END_TASK_DEFINITION_NAME}
		fi
		RESULT=`aws ${PROFILE_SPECIFIER} ecs list-tasks --cluster "${CLUSTER_NAME}" --family "${FETDN}" --output text --query 'taskArns[0]'`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain ARN for front end task definition ${FETDN}: ${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		FRONT_END_TASK_DEF_ARN=`echo ${RESULT} | tr -d \\\\015`
		if [ "${FRONT_END_TASK_DEF_ARN}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}No running front end task definition found. Moving on${FONT_NORMAL}\\n
			FRONT_END_TASK_DEF_ARN=""
		fi

		BACK_END_TASK_DEF_ARN=""
		BETDN=""
		if [ ${RELEASE_UPDATE} -eq 1 ]
		then
			BETDN=${OLD_BACK_END_TASK_DEFINITION_NAME}
		else
			BETDN=${BACK_END_TASK_DEFINITION_NAME}
		fi
		RESULT=`aws ${PROFILE_SPECIFIER} ecs list-tasks --cluster "${CLUSTER_NAME}" --family "${BETDN}" --output text --query 'taskArns[0]'`
		if [ $? -ne 0 ]
		then
			echo -e \\n${FONT_BOLD}Could not obtain ARN for back end task definition ${BETDN}: ${RESULT}${FONT_NORMAL}\\n
			exit 1
		fi
		BACK_END_TASK_DEF_ARN=`echo ${RESULT} | tr -d \\\\015`
		if [ "${BACK_END_TASK_DEF_ARN}" == "None" ]
		then
			echo -e \\n${FONT_BOLD}No running back end task definition found. Moving on${FONT_NORMAL}\\n
			BACK_END_TASK_DEF_ARN=""
		fi

		# OK -- if we found running tasks, stop them
		if [ -n "${FRONT_END_TASK_DEF_ARN}" -a ${BACKEND_UPDATE} -ne 1 ]
		then
			debug "Stopping front end task"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs stop-task --cluster "${CLUSTER_NAME}" --task "${FRONT_END_TASK_DEF_ARN}"  `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to stop task ${FRONT_END_TASK_DEF_ARN} on instance ${CLOUD_FRONT_CONTAINER_INSTANCE_ARN}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Stopped front end task"
		fi

		if [ -n "${BACK_END_TASK_DEF_ARN}" -a ${FRONTEND_UPDATE} -ne 1 ]
		then
			debug "Stopping back end task"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs stop-task --cluster "${CLUSTER_NAME}" --task "${BACK_END_TASK_DEF_ARN}"  `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to stop task ${FRONT_END_TASK_DEF_ARN} on instance ${CLOUD_BACK_CONTAINER_INSTANCE_ARN}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Stopped back end task"
		fi
	fi


	########################################################################
	#
	# Run Tasks!!
	#
	########################################################################
	debug "Running tasks!"
	if [ ${UPDATE} -ne 1 -a ${FIX} -ne 1 -a ${BACKEND_UPDATE} -ne 1 -a ${FRONTEND_UPDATE} -ne 1 ]
	then
		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			debug "Starting Search Task"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs start-task --cluster "${CLUSTER_NAME}" --task-definition "${SEARCH_TASK_DEFINITION_NAME}" --container-instances "${SEARCH_CONTAINER_INSTANCE_ARN}"  --overrides "${UNISEARCH_WEB_OVERRIDES}" --output text --query 'failures' `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${SEARCH_TASK_DEFINITION_NAME} on instance ${SEARCH_CONTAINER_INSTANCE_ARN}${FONT_NORMAL}\\n
				exit 1
			fi
			FAILURES=`echo ${RESULT} | tr -d \\\\015`
			if [ -n "${FAILURES}" -a "${FAILURES}" != "None" ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${SEARCH_TASK_DEFINITION_NAME} on instance ${SEARCH_CONTAINER_INSTANCE_ARN}: ${FAILURES}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Successfully started Search Task"
		fi
	else
		debug "Updating system. Leaving Support Task alone."
		if [ ${DEPLOY_UNISEARCH} -ne 0 ]
		then
			debug "Updating system. Leaving Search Task alone."
		fi
	fi

	# 12/12/19 -- bobp -- the 0 -ne 1 used to be a test for support-update
	if [ 0 -ne 1 ]
	then
		if [ ${FRONTEND_UPDATE} -ne 1 ]
		then
			debug "Starting Back End Task"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs start-task --cluster "${CLUSTER_NAME}" --task-definition "${BACK_END_TASK_DEFINITION_NAME}" --container-instances "${CLOUD_BACK_CONTAINER_INSTANCE_ARN}" --overrides "${CLOUD_BACK_OVERRIDES}" --output text --query 'failures' `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${BACK_END_TASK_DEFINITION_NAME} on instance ${CLOUD_BACK_CONTAINER_INSTANCE_ARN}${FONT_NORMAL}\\n
				exit 1
			fi
			FAILURES=`echo ${RESULT} | tr -d \\\\015`
			if [ -n "${FAILURES}" -a "${FAILURES}" != "None" ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${BACK_END_TASK_DEFINITION_NAME} on instance ${BACK_END_CONTAINER_INSTANCE_ARN}: ${FAILURES}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Successfully started Back End Task"
		fi

		if [ ${BACKEND_UPDATE} -ne 1 ]
		then
			debug "Starting Front End Task"
			RESULT=`aws ${PROFILE_SPECIFIER} ecs start-task --cluster "${CLUSTER_NAME}" --task-definition "${FRONT_END_TASK_DEFINITION_NAME}" --container-instances "${CLOUD_FRONT_CONTAINER_INSTANCE_ARN}" --overrides "${CLOUD_FRONT_OVERRIDES}" --output text --query 'failures' `
			if [ $? -ne 0 ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${FRONT_END_TASK_DEFINITION_NAME} on instance ${CLOUD_FRONT_CONTAINER_INSTANCE_ARN}${FONT_NORMAL}\\n
				exit 1
			fi
			FAILURES=`echo ${RESULT} | tr -d \\\\015`
			if [ -n "${FAILURES}" -a "${FAILURES}" != "None" ]
			then
				echo -e \\n${FONT_BOLD}Failed to start task definition ${FRONT_END_TASK_DEFINITION_NAME} on instance ${FRONT_END_CONTAINER_INSTANCE_ARN}: ${FAILURES}${FONT_NORMAL}\\n
				exit 1
			fi
			debug "Successfully started Front End Task"
		fi
	fi
fi # END EC2_ONLY_DEPLOYMENT -eq 09

if [ ${EC2_ONLY_DEPLOYMENT} -eq 0 ]
then
	debug "Wait about 7 minutes for everything to come up.  It is now " `date`
else
	debug "Wait about 15 minutes for everything to come up.  It is now " `date`
fi

exit 0
