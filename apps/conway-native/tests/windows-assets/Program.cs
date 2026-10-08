using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Text.Json;

if(args.Length!=3) throw new ArgumentException("Expected app assembly, source icon and source tour paths.");
using var file=File.OpenRead(args[0]);
using var pe=new PEReader(file);
var metadata=pe.GetMetadataReader();
var directory=pe.PEHeaders.CorHeader!.ResourcesDirectory;
var resources=new Dictionary<string,byte[]>();
foreach(var handle in metadata.ManifestResources){
    var resource=metadata.GetManifestResource(handle);
    if(!resource.Implementation.IsNil) continue;
    var reader=pe.GetSectionData(directory.RelativeVirtualAddress+checked((int)resource.Offset)).GetReader();
    resources.Add(metadata.GetString(resource.Name),reader.ReadBytes(reader.ReadInt32()));
}
void Check(string name,string path){
    if(!resources.TryGetValue(name,out var bytes)) throw new Exception("Resource missing from compiled app: "+name);
    if(!bytes.AsSpan().SequenceEqual(File.ReadAllBytes(path))) throw new Exception("Embedded asset differs from source: "+name);
    Console.WriteLine($"PASS: {name} embedded intact ({bytes.Length:N0} bytes)");
}
Check("Nithi.Life.AppIcon.ico",args[1]);
Check("Nithi.Life.tour.json",args[2]);
var icon=resources["Nithi.Life.AppIcon.ico"];
if(icon.Length<22||BitConverter.ToUInt16(icon,0)!=0||BitConverter.ToUInt16(icon,2)!=1)
    throw new Exception("Invalid Windows icon header");
int count=BitConverter.ToUInt16(icon,4);
if(count==0||6+16*count>icon.Length) throw new Exception("Missing icon images");
var iconSizes=new HashSet<int>();
for(int i=0;i<count;i++){
    int width=icon[6+i*16]==0?256:icon[6+i*16];
    int height=icon[6+i*16+1]==0?256:icon[6+i*16+1];
    if(width!=height) throw new Exception("App icon frames must be square");
    iconSizes.Add(width);
    uint size=BitConverter.ToUInt32(icon,6+i*16+8),offset=BitConverter.ToUInt32(icon,6+i*16+12);
    if(size==0||offset<6+16*count||(ulong)offset+size>(ulong)icon.Length) throw new Exception("Invalid icon image range");
}
if(!new[]{16,32,48,256}.All(iconSizes.Contains)) throw new Exception("Missing shell or high-resolution icon sizes");
using var tour=JsonDocument.Parse(resources["Nithi.Life.tour.json"]);
if(tour.RootElement.ValueKind!=JsonValueKind.Array||tour.RootElement.GetArrayLength()==0) throw new Exception("Missing guided tour steps");
Console.WriteLine($"PASS: {count} icon sizes and {tour.RootElement.GetArrayLength()} guided tour steps");
