# modules/metrics.py
# Map of logical CSV fields → possible Zabbix item.key_ for each field

METRIC_KEYS_MAP = {
    # CPU
    "CPU_Cores": [
        "system.cpu.num",
        'wmi.get[root/cimv2,"Select NumberOfLogicalProcessors from Win32_ComputerSystem"]',
    ],
    "%_CPU_Util": [
        "system.cpu.util",
    ],
    "Processes": [
        "proc.num",
        "proc.num[]",
    ],

    # RAM
    "RAM_Total_B": [
        "vm.memory.size[total]",
    ],
    "RAM_Avail_B": [
        "vm.memory.size[available]",
        "vm.memory.size[pavailable]",
    ],
    "RAM_Used_Direct_B": [
        "vm.memory.size[used]",
    ],
    "%_RAM_Util": [
        "vm.memory.util",
        "vm.memory.utilization",
    ],

    # # SWAP
    # "Swap_Total_B": [
    #     "system.swap.size[,total]",
    # ],
    # "Swap_Free_B": [
    #     "system.swap.free",
    #     "system.swap.size[,free]",
    # ],
    # "%_Swap_Free": [
    #     "system.swap.pfree",
    #     "system.swap.size[,pfree]",
    # ],

    # # Disks Linux
    # "Disk_Total_B_Linux": [
    #     "vfs.fs.dependent.size[/,total]",
    # ],
    # "Disk_Used_B_Linux": [
    #     "vfs.fs.dependent.size[/,used]",
    # ],
    # "%_Disk_Used_Linux": [
    #     "vfs.fs.dependent.size[/,pused]",
    # ],
    # "Disk_IO_WriteRate_Linux": [
    #     "vfs.dev.write.rate[sda]",
    # ],
    # "Disk_IO_ReadRate_Linux": [
    #     "vfs.dev.read.rate[sda]",
    # ],
    # "Disk_IO_Util_Linux": [
    #     "vfs.dev.util[sda]",
    # ],

    # # Disks Windows
    # "Disk_Total_B_Win": [
    #     "vfs.fs.dependent.size[C:,total]",
    # ],
    # "Disk_Used_B_Win": [
    #     "vfs.fs.dependent.size[C:,used]",
    # ],
    # "%_Disk_Used_Win": [
    #     "vfs.fs.dependent.size[C:,pused]",
    # ],
    # "Disk_IO_Writes_Key_Win": [
    #     r'perf_counter_en["\PhysicalDisk(0 C:)\Disk Reads/sec",60]',
    # ],
    # "Disk_IO_Reads_Key_Win": [
    #     r'perf_counter_en["\PhysicalDisk(0 C:)\Disk Writes/sec",60]',
    # ],
    # "Disk_IO_Idle_Win": [
    #     r'perf_counter_en["\PhysicalDisk(0 C:)\% Idle Time",60]',
    # ],
}
