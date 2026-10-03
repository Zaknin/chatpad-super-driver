#include "Topology.h"
#include <algorithm>
#include <iomanip>
#include <set>
#include <sstream>
namespace chatpad {
bool ParseConfiguration(const std::vector<uint8_t>& raw, uint8_t& configuration,
                        std::vector<InterfaceInfo>& interfaces, std::string& error) {
    configuration=0; interfaces.clear(); error.clear();
    auto fail=[&](const char* reason) {error=reason;interfaces.clear();return false;};
    if(raw.size()<9 || raw[0]!=9 || raw[1]!=2) return fail("invalid configuration header");
    const size_t total=static_cast<size_t>(raw[2])|(static_cast<size_t>(raw[3])<<8);
    if(total!=raw.size() || raw[5]==0) return fail("configuration length/value mismatch");
    std::set<uint8_t> numbers; std::set<uint16_t> settings;
    size_t expectedEndpoints=0;
    for(size_t offset=9;offset<total;) {
        if(total-offset<2) return fail("truncated descriptor header");
        const size_t length=raw[offset];const uint8_t type=raw[offset+1];
        if(length<2 || length>total-offset) return fail("invalid descriptor length");
        if(type==4) {
            if(length<9) return fail("short interface descriptor");
            if(!interfaces.empty() && interfaces.back().endpoints.size()!=expectedEndpoints)
                return fail("endpoint count mismatch");
            const uint8_t number=raw[offset+2],alternate=raw[offset+3];
            const auto identity=static_cast<uint16_t>((number<<8)|alternate);
            if(!settings.insert(identity).second) return fail("duplicate interface/alternate");
            numbers.insert(number);expectedEndpoints=raw[offset+4];
            interfaces.push_back({number,alternate,{}});
        } else if(type==5) {
            if(length<7 || interfaces.empty()) return fail("endpoint without valid interface");
            EndpointInfo endpoint{raw[offset+2],static_cast<uint8_t>(raw[offset+3]&3),
                static_cast<uint16_t>((raw[offset+4]|(raw[offset+5]<<8))&0x7ff)};
            if((endpoint.address&0x0f)==0 || endpoint.maxPacketSize==0) return fail("invalid endpoint");
            const auto& endpoints=interfaces.back().endpoints;
            if(std::any_of(endpoints.begin(),endpoints.end(),[&](const auto& e){return e.address==endpoint.address;}))
                return fail("duplicate endpoint");
            interfaces.back().endpoints.push_back(endpoint);
        }
        offset+=length;
    }
    if(interfaces.empty() || interfaces.back().endpoints.size()!=expectedEndpoints || numbers.size()!=raw[4])
        return fail("configuration interface/endpoint count mismatch");
    configuration=raw[5];return true;
}
bool RequiredTopology(const std::vector<InterfaceInfo>& interfaces) {
    auto pipe=[&](uint8_t number,uint8_t address) {
        for(const auto& i:interfaces) if(i.number==number && i.alternateSetting==0)
            for(const auto& e:i.endpoints) if(e.address==address && e.type==3 && e.maxPacketSize==32) return true;
        return false;
    };
    return pipe(0,0x81)&&pipe(0,0x01)&&pipe(2,0x84);
}
std::string JsonString(const std::string& value) {
    std::ostringstream out;out<<'"';
    for(unsigned char c:value) {
        switch(c) {case '"':out<<"\\\"";break;case '\\':out<<"\\\\";break;
        case '\n':out<<"\\n";break;case '\r':out<<"\\r";break;case '\t':out<<"\\t";break;
        default:if(c<0x20) out<<"\\u"<<std::hex<<std::setw(4)<<std::setfill('0')<<static_cast<unsigned>(c);
                else out<<c;break;}
    }
    out<<'"';return out.str();
}
std::string TopologyJson(const DeviceInfo& device,const std::vector<uint8_t>& raw,const std::string& provenance) {
    std::ostringstream out;
    out<<"{\"schema\":1,\"provenance\":"<<JsonString(provenance)<<",\"vid\":"<<device.vid
       <<",\"pid\":"<<device.pid<<",\"instance\":"<<JsonString(device.instanceId)
       <<",\"activeConfiguration\":"<<static_cast<unsigned>(device.configuration)<<",\"interfaces\":[";
    bool first=true;
    for(const auto& i:device.interfaces) {
        if(!first)out<<',';first=false;
        out<<"{\"number\":"<<static_cast<unsigned>(i.number)<<",\"alternateSetting\":"<<static_cast<unsigned>(i.alternateSetting)<<",\"endpoints\":[";
        bool firstPipe=true;
        for(const auto& e:i.endpoints) {
            if(!firstPipe)out<<',';firstPipe=false;
            out<<"{\"address\":"<<static_cast<unsigned>(e.address)<<",\"type\":"<<static_cast<unsigned>(e.type)<<",\"maxPacketSize\":"<<e.maxPacketSize<<'}';
        }
        out<<"]}";
    }
    out<<"],\"configurationDescriptorBytes\":[";first=true;
    for(auto b:raw) {if(!first)out<<',';first=false;out<<static_cast<unsigned>(b);}
    out<<"]}";return out.str();
}
}
