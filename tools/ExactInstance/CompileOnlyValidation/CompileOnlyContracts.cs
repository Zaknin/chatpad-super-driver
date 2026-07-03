using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Chatpad.ExactInstance.NativeInterop
{
    internal interface ICompileOnlyContractSink
    {
        void Accept<T>(T value);
    }

    internal static class ChatpadNativeInteropCompileOnlyContracts
    {
        private delegate IntPtr SetupDiCreateDeviceInfoListDelegate(ref Guid classGuid, IntPtr hwndParent);
        private delegate bool SetupDiDestroyDeviceInfoListDelegate(IntPtr deviceInfoSet);
        private delegate bool SetupDiOpenDeviceInfoDelegate(IntPtr deviceInfoSet, string deviceInstanceId, IntPtr hwndParent, uint openFlags, ref SP_DEVINFO_DATA deviceInfoData);
        private delegate bool SetupDiGetDeviceInstanceIdDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, StringBuilder deviceInstanceId, uint deviceInstanceIdSize, out uint requiredSize);
        private delegate bool SetupDiGetDevicePropertyDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, ref DEVPROPKEY propertyKey, out uint propertyType, IntPtr propertyBuffer, uint propertyBufferSize, out uint requiredSize, uint flags);
        private delegate bool SetupDiGetDeviceRegistryPropertyDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, uint property, out uint propertyRegDataType, IntPtr propertyBuffer, uint propertyBufferSize, out uint requiredSize);
        private delegate bool SetupDiBuildDriverInfoListDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, uint driverType);
        private delegate bool SetupDiDestroyDriverInfoListDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, uint driverType);
        private delegate bool SetupDiEnumDriverInfoDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, uint driverType, uint memberIndex, ref SP_DRVINFO_DATA_W driverInfoData);
        private delegate bool SetupDiGetDriverInfoDetailDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, ref SP_DRVINFO_DATA_W driverInfoData, IntPtr driverInfoDetailData, uint driverInfoDetailDataSize, out uint requiredSize);
        private delegate bool SetupDiGetDriverInstallParamsDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, ref SP_DRVINFO_DATA_W driverInfoData, ref SP_DEVINSTALL_PARAMS_W driverInstallParams);
        private delegate bool SetupDiSetSelectedDriverDelegate(IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, ref SP_DRVINFO_DATA_W driverInfoData);
        private delegate bool DiInstallDeviceDelegate(IntPtr hwndParent, IntPtr deviceInfoSet, ref SP_DEVINFO_DATA deviceInfoData, ref SP_DRVINFO_DATA_W driverInfoData, uint flags, out bool needReboot);

        internal static void BindNativeSignaturesForCompilerOnly(ICompileOnlyContractSink sink)
        {
            sink.Accept<SetupDiCreateDeviceInfoListDelegate>(SetupApiNewdevDeclarations.SetupDiCreateDeviceInfoList);
            sink.Accept<SetupDiDestroyDeviceInfoListDelegate>(SetupApiNewdevDeclarations.SetupDiDestroyDeviceInfoList);
            sink.Accept<SetupDiOpenDeviceInfoDelegate>(SetupApiNewdevDeclarations.SetupDiOpenDeviceInfoW);
            sink.Accept<SetupDiGetDeviceInstanceIdDelegate>(SetupApiNewdevDeclarations.SetupDiGetDeviceInstanceIdW);
            sink.Accept<SetupDiGetDevicePropertyDelegate>(SetupApiNewdevDeclarations.SetupDiGetDevicePropertyW);
            sink.Accept<SetupDiGetDeviceRegistryPropertyDelegate>(SetupApiNewdevDeclarations.SetupDiGetDeviceRegistryPropertyW);
            sink.Accept<SetupDiBuildDriverInfoListDelegate>(SetupApiNewdevDeclarations.SetupDiBuildDriverInfoList);
            sink.Accept<SetupDiDestroyDriverInfoListDelegate>(SetupApiNewdevDeclarations.SetupDiDestroyDriverInfoList);
            sink.Accept<SetupDiEnumDriverInfoDelegate>(SetupApiNewdevDeclarations.SetupDiEnumDriverInfoW);
            sink.Accept<SetupDiGetDriverInfoDetailDelegate>(SetupApiNewdevDeclarations.SetupDiGetDriverInfoDetailW);
            sink.Accept<SetupDiGetDriverInstallParamsDelegate>(SetupApiNewdevDeclarations.SetupDiGetDriverInstallParamsW);
            sink.Accept<SetupDiSetSelectedDriverDelegate>(SetupApiNewdevDeclarations.SetupDiSetSelectedDriverW);
            sink.Accept<DiInstallDeviceDelegate>(SetupApiNewdevDeclarations.DiInstallDevice);
        }

        internal static void BindStructureContractsForCompilerOnly(ICompileOnlyContractSink sink)
        {
            var deviceInfo = default(SP_DEVINFO_DATA);
            deviceInfo.cbSize = unchecked((uint)Marshal.SizeOf<SP_DEVINFO_DATA>());
            sink.Accept(deviceInfo);

            var installParams = default(SP_DEVINSTALL_PARAMS_W);
            installParams.cbSize = unchecked((uint)Marshal.SizeOf<SP_DEVINSTALL_PARAMS_W>());
            sink.Accept(installParams);

            var driverInfo = default(SP_DRVINFO_DATA_W);
            driverInfo.cbSize = unchecked((uint)Marshal.SizeOf<SP_DRVINFO_DATA_W>());
            sink.Accept(driverInfo);

            var driverInfoDetail = default(SP_DRVINFO_DETAIL_DATA_W);
            driverInfoDetail.cbSize = unchecked((uint)Marshal.SizeOf<SP_DRVINFO_DETAIL_DATA_W>());
            sink.Accept(driverInfoDetail);

            sink.Accept(default(DEVPROPKEY));
            sink.Accept(new ChatpadDeviceInfoSetHandleToken(IntPtr.Zero));
        }
    }
}
