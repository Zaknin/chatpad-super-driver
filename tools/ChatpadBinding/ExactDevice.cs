// Narrow SetupAPI/newdev executor. ABI follows Windows SDK 10.0.26100.0 and
// tools/ExactInstance/NativeInterop declarations; no legacy phase wrappers reused.
// Invoked only by the separately gated PowerShell entrypoint. No global update API.
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
namespace Chatpad.Binding {
 public static class ExactDevice {
  [StructLayout(LayoutKind.Sequential)] struct Device { public uint Size; public Guid Class; public uint DevInst; public UIntPtr Reserved; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Params {
   public uint Size, Flags, FlagsEx; public IntPtr Parent, Handler, Context, Queue; public UIntPtr Reserved1; public uint Reserved2;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string DriverPath;
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Driver {
   public uint Size, Type; public UIntPtr Reserved;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Description;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Manufacturer;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Provider;
   public System.Runtime.InteropServices.ComTypes.FILETIME Date; public ulong Version;
  }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Detail {
   public uint Size; public System.Runtime.InteropServices.ComTypes.FILETIME Date; public uint Offset, Length; public UIntPtr Reserved;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Section;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string Inf;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Description;
   [MarshalAs(UnmanagedType.ByValTStr, SizeConst=1)] public string HardwareId;
  }
  [DllImport("setupapi.dll", SetLastError=true)] static extern IntPtr SetupDiCreateDeviceInfoList(IntPtr guid, IntPtr parent);
  [DllImport("setupapi.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiOpenDeviceInfoW(IntPtr set,string id,IntPtr parent,uint flags,ref Device dev);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiGetDeviceInstanceIdW(IntPtr set,ref Device dev,StringBuilder id,uint size,out uint required);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiGetDeviceInstallParamsW(IntPtr set,ref Device dev,ref Params p);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiSetDeviceInstallParamsW(IntPtr set,ref Device dev,ref Params p);
  [DllImport("setupapi.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiBuildDriverInfoList(IntPtr set,ref Device dev,uint type);
  [DllImport("setupapi.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiDestroyDriverInfoList(IntPtr set,ref Device dev,uint type);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiEnumDriverInfoW(IntPtr set,ref Device dev,uint type,uint index,ref Driver driver);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiGetDriverInfoDetailW(IntPtr set,ref Device dev,ref Driver driver,IntPtr detail,uint size,out uint required);
  [DllImport("setupapi.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool SetupDiSetSelectedDriverW(IntPtr set,ref Device dev,ref Driver driver);
  [DllImport("newdev.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] static extern bool DiInstallDevice(IntPtr parent,IntPtr set,ref Device dev,ref Driver driver,uint flags,[MarshalAs(UnmanagedType.Bool)]out bool reboot);
  static void Check(bool ok) { if(!ok) throw new Win32Exception(Marshal.GetLastWin32Error()); }
  static string Version(ulong v) { return String.Format("{0}.{1}.{2}.{3}",v>>48,(v>>32)&65535,(v>>16)&65535,v&65535); }
  public static bool InspectCandidate(string id,string inf,string section,string provider,string version) { return Run(id,inf,section,provider,version,false); }
  public static bool Install(string id,string inf,string section,string provider,string version) { return Run(id,inf,section,provider,version,true); }
  static bool Run(string id,string inf,string section,string provider,string version,bool execute) {
   if(!System.Text.RegularExpressions.Regex.IsMatch(id,@"^USB\\VID_045E&PID_028E\\[^\\]+$",System.Text.RegularExpressions.RegexOptions.IgnoreCase)) throw new ArgumentException("Exact physical instance required");
   if(!System.IO.Path.IsPathRooted(inf) || inf.Length>=260) throw new ArgumentException("Absolute bounded INF path required");
   IntPtr set=SetupDiCreateDeviceInfoList(IntPtr.Zero,IntPtr.Zero); if(set==new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
   Device dev=new Device(); dev.Size=(uint)Marshal.SizeOf(typeof(Device)); bool built=false;
   try {
    Check(SetupDiOpenDeviceInfoW(set,id,IntPtr.Zero,0,ref dev)); uint required; var actual=new StringBuilder(512);
    Check(SetupDiGetDeviceInstanceIdW(set,ref dev,actual,512,out required)); if(!String.Equals(id,actual.ToString(),StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("Instance mismatch");
    Params p=new Params(); p.Size=(uint)Marshal.SizeOf(typeof(Params)); Check(SetupDiGetDeviceInstallParamsW(set,ref dev,ref p));
    p.Flags|=0x00010000; p.DriverPath=inf; Check(SetupDiSetDeviceInstallParamsW(set,ref dev,ref p));
    Check(SetupDiBuildDriverInfoList(set,ref dev,2)); built=true; Driver selected=new Driver(); int matches=0;
    for(uint i=0;;i++) {
     Driver d=new Driver(); d.Size=(uint)Marshal.SizeOf(typeof(Driver));
     if(!SetupDiEnumDriverInfoW(set,ref dev,2,i,ref d)) { int e=Marshal.GetLastWin32Error(); if(e==259) break; throw new Win32Exception(e); }
     uint bytes; SetupDiGetDriverInfoDetailW(set,ref dev,ref d,IntPtr.Zero,0,out bytes); int error=Marshal.GetLastWin32Error();
     if(error!=122 || bytes<Marshal.SizeOf(typeof(Detail)) || bytes>1048576) throw new InvalidOperationException("Invalid driver detail sizing");
     IntPtr memory=Marshal.AllocHGlobal((int)bytes);
     try {
      Marshal.WriteInt32(memory,Marshal.SizeOf(typeof(Detail))); Check(SetupDiGetDriverInfoDetailW(set,ref dev,ref d,memory,bytes,out required));
      Detail detail=(Detail)Marshal.PtrToStructure(memory,typeof(Detail));
      string hardwareId=Marshal.PtrToStringUni(IntPtr.Add(memory,(int)Marshal.OffsetOf(typeof(Detail),"HardwareId")));
      if(String.Equals(hardwareId,@"USB\VID_045E&PID_028E",StringComparison.OrdinalIgnoreCase) && String.Equals(System.IO.Path.GetFullPath(detail.Inf),System.IO.Path.GetFullPath(inf),StringComparison.OrdinalIgnoreCase) && String.Equals(detail.Section,section,StringComparison.OrdinalIgnoreCase) && String.Equals(d.Provider,provider,StringComparison.Ordinal) && Version(d.Version)==version) { selected=d; matches++; }
     } finally { Marshal.FreeHGlobal(memory); }
    }
    if(matches!=1) throw new InvalidOperationException("Exactly one captured INF/section/provider/version node required; matches="+matches);
    if(!execute) return true;
    Check(SetupDiSetSelectedDriverW(set,ref dev,ref selected)); bool reboot;
    Check(DiInstallDevice(IntPtr.Zero,set,ref dev,ref selected,0,out reboot)); return reboot;
   } finally {
    bool listClean=!built || SetupDiDestroyDriverInfoList(set,ref dev,2); int listError=Marshal.GetLastWin32Error();
    bool setClean=SetupDiDestroyDeviceInfoList(set); int setError=Marshal.GetLastWin32Error();
    if(!listClean || !setClean) throw new Win32Exception(!listClean?listError:setError,"SetupAPI cleanup failed");
   }
  }
 }
}
