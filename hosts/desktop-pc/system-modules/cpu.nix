{...}:
{
	boot.kernelModules = [ "kvm-amd" ];
	hardware.cpu.amd.updateMicrocode = true;
	powerManagement.cpuFreqGovernor = "performance";
}
