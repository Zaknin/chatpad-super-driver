#include "Topology.h"
#include <iostream>
#include <stdexcept>
using namespace chatpad;
static int passed=0;
static void Check(bool value,const char* name) { if(!value) throw std::runtime_error(name); ++passed; }
int main() {
 try {
  // Independent minimal descriptor fixture; no hardware calls.
  std::vector<uint8_t> fixture={9,2,48,0,2,1,0,0xA0,250,
   9,4,0,0,2,0xff,0x5d,1,0, 7,5,0x81,3,32,0,4, 7,5,1,3,32,0,8,
   9,4,2,0,1,0xff,0x5d,2,0, 7,5,0x84,3,32,0,16};
  uint8_t config=0; std::vector<InterfaceInfo> interfaces;std::string error;
  Check(ParseConfiguration(fixture,config,interfaces,error),"valid descriptor rejected");
  Check(config==1 && interfaces.size()==2,"configuration/interface count");
  Check(RequiredTopology(interfaces),"required endpoint topology");
  auto broken=fixture;broken.pop_back();Check(!ParseConfiguration(broken,config,interfaces,error),"truncated total length");
  broken=fixture;broken[9]=0;Check(!ParseConfiguration(broken,config,interfaces,error),"zero descriptor length");
  broken=fixture;broken[10]=5;Check(!ParseConfiguration(broken,config,interfaces,error),"endpoint before interface");
  broken=fixture;broken[27]=0x81;Check(!ParseConfiguration(broken,config,interfaces,error),"duplicate endpoint");
  broken=fixture;broken[9]=8;Check(!ParseConfiguration(broken,config,interfaces,error),"short interface descriptor");
  broken=fixture;broken[13]=3;Check(!ParseConfiguration(broken,config,interfaces,error),"endpoint count mismatch");
  Check(ParseConfiguration(fixture,config,interfaces,error),"repeat good descriptor");
  interfaces[1].endpoints[0].address=0x82;Check(!RequiredTopology(interfaces),"incorrect Chatpad endpoint");
  Check(JsonString("a\"\\\n")=="\"a\\\"\\\\\\n\"","JSON escaping");
  DeviceInfo device;device.instanceId="redacted";device.vid=0x045e;device.pid=0x028e;device.configuration=1;
  Check(TopologyJson(device,fixture,"offline fixture").find("offline fixture")!=std::string::npos,"JSON provenance");
  std::cout<<"PASS topology "<<passed<<" assertions\n";return 0;
 } catch(const std::exception& e) {std::cerr<<"FAIL topology "<<passed<<": "<<e.what()<<'\n';return 1;}
}
