import os
import subprocess

# Check if running as root
def check_root():
    if os.geteuid() != 0:
        print("This script must be run as root. Please use sudo or run as root.")
        exit(1)

# Install NFS utilities
def install_nfs_utilities():
    if subprocess.run(["which", "exportfs"], capture_output=True).returncode != 0:
        print("NFS utilities are not installed. Installing NFS utilities...")
        if os.path.exists("/etc/debian_version"):
            subprocess.run(["apt", "update"], check=True)
            subprocess.run(["apt", "install", "-y", "nfs-kernel-server"], check=True)
        elif os.path.exists("/etc/redhat-release"):
            subprocess.run(["yum", "install", "-y", "nfs-utils"], check=True)
        else:
            print("Unsupported operating system. Please install the NFS utilities manually.")
            exit(1)
    else:
        print("NFS utilities are already installed.")

    print("Starting and enabling NFS server...")
    subprocess.run(["systemctl", "start", "nfs-kernel-server"], check=True)
    subprocess.run(["systemctl", "enable", "nfs-kernel-server"], check=True)

# Configure NFS exports
def configure_nfs_exports(template_dir):
    export_entry = f"{template_dir} *(rw,sync,no_subtree_check,no_root_squash)"
    exports_file = "/etc/exports"

    # Read the current exports file and remove any existing entries for template_dir
    with open(exports_file, "r") as file:
        lines = file.readlines()

    with open(exports_file, "w") as file:
        for line in lines:
            if template_dir not in line:
                file.write(line)
        file.write(f"{export_entry}\n")

    # Apply the exports
    subprocess.run(["exportfs", "-ra"], check=True)
    subprocess.run(["systemctl", "restart", "nfs-kernel-server"], check=True)

# Menu function
def menu():
    while True:
        print("1) Convert and create VM")
        print("2) Download VulnHub template")
        print("3) Manage VMs")
        print("4) Exit")
        choice = input("Please enter your choice: ")

        if choice == "1":
            convert_and_create_vm()
        elif choice == "2":
            download_vuln()
        elif choice == "3":
            manage_vms()
        elif choice == "4":
            print("Exiting...")
            break
        else:
            print("Invalid option. Please try again.")

# Placeholder functions for menu options
def convert_and_create_vm():
    vm_id = input("Enter VM ID: ")
    vm_name = input("Enter VM name: ")
    template_file = input("Enter path to template file: ")
    storage_type = input("Enter storage type (1 for LVM-Thin, 2 for Directory): ")
    # Implement the conversion and VM creation logic here
    print(f"Converting and creating VM {vm_name} with ID {vm_id}...")

def download_vuln():
    download_link = input("Enter the download link: ")
    # Implement the template download logic here
    print(f"Downloading template from {download_link}...")

def manage_vms():
    # Implement the VM management logic here
    print("Managing VMs...")

if __name__ == "__main__":
    check_root()
    install_nfs_utilities()

    template_dir = "/var/lib/vz/template/imported_templates"
    if not os.path.exists(template_dir):
        os.makedirs(template_dir)
    os.chmod(template_dir, 0o775)

    configure_nfs_exports(template_dir)
    print("NFS configuration is complete. Proceeding to the menu...")

    menu()
