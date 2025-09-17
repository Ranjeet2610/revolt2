#!/bin/bash

# =============================================================================
# Revolt Bot - Quick AWS Deployment Script
# =============================================================================
# This script provides one-command deployment to AWS
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first:"
        echo "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
        echo "unzip awscliv2.zip"
        echo "sudo ./aws/install"
        exit 1
    fi
    print_status "AWS CLI is installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run:"
        echo "aws configure"
        exit 1
    fi
    print_status "AWS credentials configured"
}

# Function to deploy using CloudFormation
deploy_cloudformation() {
    local stack_name=${1:-"revolt-bot-stack"}
    local key_pair=${2:-"default-keypair"}
    local instance_type=${3:-"t3.medium"}
    
    print_info "Deploying Revolt Bot using CloudFormation..."
    print_info "Stack Name: $stack_name"
    print_info "Key Pair: $key_pair"
    print_info "Instance Type: $instance_type"
    
    aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-body file://cloudformation-template.yaml \
        --parameters ParameterKey=KeyPairName,ParameterValue="$key_pair" \
                    ParameterKey=InstanceType,ParameterValue="$instance_type" \
        --capabilities CAPABILITY_IAM
    
    print_info "Stack creation initiated. Waiting for completion..."
    aws cloudformation wait stack-create-complete --stack-name "$stack_name"
    
    # Get outputs
    local public_ip=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
        --output text)
    
    local dashboard_url=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
        --output text)
    
    print_status "Deployment completed!"
    print_status "Public IP: $public_ip"
    print_status "Dashboard URL: $dashboard_url"
}

# Function to deploy using direct SSH
deploy_ssh() {
    local host=${1}
    local key_file=${2}
    local username=${3:-"aws-bot"}
    
    if [ -z "$host" ] || [ -z "$key_file" ]; then
        print_error "Host and key file are required for SSH deployment"
        echo "Usage: $0 ssh <host> <key-file> [username]"
        exit 1
    fi
    
    print_info "Deploying to $host via SSH..."
    
    # Copy files to remote host
    print_info "Copying files to remote host..."
    scp -i "$key_file" -r . ubuntu@"$host":/home/ubuntu/revolt-bot/
    
    # Execute deployment on remote host
    print_info "Executing deployment on remote host..."
    ssh -i "$key_file" ubuntu@"$host" << EOF
        cd /home/ubuntu/revolt-bot
        chmod +x aws-start.sh
        ./aws-start.sh "$username"
EOF
    
    print_status "Deployment completed!"
    print_status "Bot should be running on http://$host:PORT"
}

# Function to deploy using Docker
deploy_docker() {
    local host=${1}
    local key_file=${2}
    
    if [ -z "$host" ] || [ -z "$key_file" ]; then
        print_error "Host and key file are required for Docker deployment"
        echo "Usage: $0 docker <host> <key-file>"
        exit 1
    fi
    
    print_info "Deploying using Docker to $host..."
    
    # Copy files to remote host
    print_info "Copying files to remote host..."
    scp -i "$key_file" -r . ubuntu@"$host":/home/ubuntu/revolt-bot/
    
    # Execute Docker deployment on remote host
    print_info "Executing Docker deployment on remote host..."
    ssh -i "$key_file" ubuntu@"$host" << EOF
        cd /home/ubuntu/revolt-bot
        sudo apt update
        sudo apt install -y docker.io docker-compose
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ubuntu
        docker-compose up -d
EOF
    
    print_status "Docker deployment completed!"
    print_status "Bot should be running on http://$host:3000"
}

# Main function
main() {
    echo "🚀 Revolt Bot - AWS Deployment Script"
    echo "====================================="
    
    case "${1:-help}" in
        "cloudformation"|"cf")
            check_aws_cli
            check_aws_credentials
            deploy_cloudformation "$2" "$3" "$4"
            ;;
        "ssh")
            deploy_ssh "$2" "$3" "$4"
            ;;
        "docker")
            deploy_docker "$2" "$3"
            ;;
        "help"|*)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  cloudformation [stack-name] [key-pair] [instance-type]  Deploy using CloudFormation"
            echo "  ssh <host> <key-file> [username]                        Deploy via SSH"
            echo "  docker <host> <key-file>                               Deploy using Docker"
            echo "  help                                                   Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 cloudformation my-bot-stack my-keypair t3.medium"
            echo "  $0 ssh 1.2.3.4 ~/.ssh/my-key.pem mybot"
            echo "  $0 docker 1.2.3.4 ~/.ssh/my-key.pem"
            ;;
    esac
}

# Run main function
main "$@"
