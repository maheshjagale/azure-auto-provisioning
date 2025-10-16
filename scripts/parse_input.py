#!/usr/bin/env python3
"""
Parse user input and generate Terraform variable values
This script reads server_request.json and creates terraform.tfvars
"""

import json
import sys
import os

def validate_input(data):
    """Validate required fields in input"""
    required_fields = ['environment', 'vm_count', 'vm_size', 'location', 'project_name']
    
    for field in required_fields:
        if field not in data:
            print(f"❌ Error: Missing required field '{field}'")
            return False
    
    # Validate vm_count
    if not isinstance(data['vm_count'], int) or data['vm_count'] < 1:
        print("❌ Error: vm_count must be a positive integer")
        return False
    
    # Validate environment
    valid_envs = ['dev', 'staging', 'production']
    if data['environment'] not in valid_envs:
        print(f"❌ Error: environment must be one of {valid_envs}")
        return False
    
    print("✅ Input validation passed")
    return True

def parse_input(input_file, output_file):
    """Parse JSON input and generate Terraform tfvars file"""
    
    try:
        # Read input JSON
        with open(input_file, 'r') as f:
            data = json.load(f)
        
        print(f"📄 Reading input from: {input_file}")
        
        # Validate input
        if not validate_input(data):
            sys.exit(1)
        
        # Generate Terraform tfvars content
        tfvars_content = f"""# Auto-generated Terraform variables
# Generated from: {input_file}

environment      = "{data['environment']}"
project_name     = "{data['project_name']}"
location         = "{data['location']}"
vm_count         = {data['vm_count']}
vm_size          = "{data['vm_size']}"
admin_username   = "{data.get('admin_username', 'azureuser')}"
os_type          = "{data.get('os_type', 'linux')}"
"""
        
        # Add tags if present
        if 'tags' in data and data['tags']:
            tfvars_content += "\ntags = {\n"
            for key, value in data['tags'].items():
                tfvars_content += f'  {key} = "{value}"\n'
            tfvars_content += "}\n"
        
        # Write to terraform.tfvars
        with open(output_file, 'w') as f:
            f.write(tfvars_content)
        
        print(f"✅ Generated Terraform variables: {output_file}")
        print("\n📋 Configuration Summary:")
        print(f"   Environment: {data['environment']}")
        print(f"   Project: {data['project_name']}")
        print(f"   Location: {data['location']}")
        print(f"   VM Count: {data['vm_count']}")
        print(f"   VM Size: {data['vm_size']}")
        
        return True
        
    except FileNotFoundError:
        print(f"❌ Error: Input file '{input_file}' not found")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON in input file: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    input_file = "inputs/server_request.json"
    output_file = "terraform/terraform.tfvars"
    
    if parse_input(input_file, output_file):
        print("\n🎉 Input parsing completed successfully!")
        sys.exit(0)
    else:
        sys.exit(1)
