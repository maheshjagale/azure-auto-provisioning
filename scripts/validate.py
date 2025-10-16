#!/usr/bin/env python3
"""
Validate provisioned infrastructure
Checks if all resources were created successfully
"""

import subprocess
import json
import sys
import time

def run_command(command):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"❌ Command failed: {command}")
        print(f"Error: {e.stderr}")
        return None

def check_terraform_state():
    """Check if Terraform state exists and is valid"""
    print("\n🔍 Checking Terraform state...")
    
    result = run_command("cd terraform && terraform show -json")
    if not result:
        return False
    
    try:
        state = json.loads(result)
        if 'values' in state and 'root_module' in state['values']:
            print("✅ Terraform state is valid")
            return True
    except json.JSONDecodeError:
        pass
    
    print("❌ Invalid Terraform state")
    return False

def get_terraform_outputs():
    """Retrieve Terraform outputs"""
    print("\n📊 Retrieving Terraform outputs...")
    
    result = run_command("cd terraform && terraform output -json")
    if not result:
        return None
    
    try:
        outputs = json.loads(result)
        return outputs
    except json.JSONDecodeError:
        print("❌ Failed to parse Terraform outputs")
        return None

def validate_resources(outputs):
    """Validate that all expected resources exist"""
    print("\n✓ Validating provisioned resources...")
    
    validation_passed = True
    
    # Check resource group
    if 'resource_group_name' in outputs:
        rg_name = outputs['resource_group_name']['value']
        print(f"  ✓ Resource Group: {rg_name}")
    else:
        print("  ✗ Resource Group not found")
        validation_passed = False
    
    # Check VMs
    if 'vm_names' in outputs:
        vm_names = outputs['vm_names']['value']
        print(f"  ✓ Virtual Machines: {len(vm_names)} created")
        for vm in vm_names:
            print(f"    - {vm}")
    else:
        print("  ✗ Virtual Machines not found")
        validation_passed = False
    
    # Check Public IPs
    if 'vm_public_ips' in outputs:
        public_ips = outputs['vm_public_ips']['value']
        print(f"  ✓ Public IPs: {len(public_ips)} assigned")
        for ip in public_ips:
            print(f"    - {ip}")
    else:
        print("  ✗ Public IPs not found")
        validation_passed = False
    
    # Check Private IPs
    if 'vm_private_ips' in outputs:
        private_ips = outputs['vm_private_ips']['value']
        print(f"  ✓ Private IPs: {len(private_ips)} assigned")
    else:
        print("  ✗ Private IPs not found")
        validation_passed = False
    
    return validation_passed

def ping_vms(outputs):
    """Test connectivity to VMs"""
    print("\n🌐 Testing VM connectivity...")
    
    if 'vm_public_ips' not in outputs:
        print("⚠️  Skipping connectivity test - no public IPs found")
        return True
    
    public_ips = outputs['vm_public_ips']['value']
    
    for i, ip in enumerate(public_ips, 1):
        print(f"  Testing VM {i} ({ip})...")
        
        # Ping test (1 packet, 2 second timeout)
        result = subprocess.run(
            f"ping -c 1 -W 2 {ip}",
            shell=True,
            capture_output=True
        )
        
        if result.returncode == 0:
            print(f"    ✓ VM {i} is reachable")
        else:
            print(f"    ⚠️  VM {i} is not responding to ping (may be firewall)")
    
    return True

def generate_report(outputs):
    """Generate validation report"""
    print("\n" + "="*60)
    print("📋 PROVISIONING VALIDATION REPORT")
    print("="*60)
    
    if not outputs:
        print("❌ No outputs available")
        return
    
    summary = outputs.get('provisioning_summary', {}).get('value', {})
    
    print(f"\n🎯 Environment: {summary.get('environment', 'N/A')}")
    print(f"📦 Project: {summary.get('project_name', 'N/A')}")
    print(f"🌍 Location: {summary.get('location', 'N/A')}")
    print(f"🖥️  VM Count: {summary.get('vm_count', 'N/A')}")
    print(f"💻 VM Size: {summary.get('vm_size', 'N/A')}")
    print(f"🐧 OS Type: {summary.get('os_type', 'N/A')}")
    print(f"⏰ Created: {summary.get('creation_time', 'N/A')}")
    
    # Connection info
    if 'connection_commands' in outputs:
        commands = outputs['connection_commands']['value']
        print(f"\n🔐 Connection Commands:")
        for i, cmd in enumerate(commands, 1):
            print(f"  VM {i}: {cmd}")
    
    print("\n" + "="*60)
    print("✅ VALIDATION COMPLETED")
    print("="*60 + "\n")

def main():
    """Main validation workflow"""
    print("🚀 Starting infrastructure validation...")
    
    # Step 1: Check Terraform state
    if not check_terraform_state():
        print("\n❌ Validation failed: Invalid Terraform state")
        sys.exit(1)
    
    # Step 2: Get outputs
    outputs = get_terraform_outputs()
    if not outputs:
        print("\n❌ Validation failed: Could not retrieve outputs")
        sys.exit(1)
    
    # Step 3: Validate resources
    if not validate_resources(outputs):
        print("\n❌ Validation failed: Missing resources")
        sys.exit(1)
    
    # Step 4: Test connectivity (non-blocking)
    ping_vms(outputs)
    
    # Step 5: Generate report
    generate_report(outputs)
    
    print("🎉 All validation checks passed!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
