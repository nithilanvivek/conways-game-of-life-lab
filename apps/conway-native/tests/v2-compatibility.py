"""Exercise the original v2 validator and saved-list filter without creating Tk UI."""
import ast,json,os,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[3]
source=root/'assets/conways-game-of-life/Conway.py'
if not source.exists():source=Path(__file__).parent/'fixtures/v2-original-source.py'
tree=ast.parse(source.read_text())
old=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='GameOfLifeApp')
methods={'validate_canvas_data','validate_rule_values','read_canvas_file','get_saved_canvas_names'}
body=[n for n in old.body if isinstance(n,(ast.Assign,ast.AnnAssign)) or isinstance(n,ast.FunctionDef) and n.name in methods]
cls=ast.ClassDef(name='LegacyValidator',bases=[],keywords=[],body=body,decorator_list=[])
module=ast.fix_missing_locations(ast.Module(body=[cls],type_ignores=[]))
namespace={'os':os,'json':json};exec(compile(module,str(source),'exec'),namespace)
legacy=namespace['LegacyValidator']()
files=root/'tmp/conway-native-tests'
if not (files/'swift.life.json.sparse').exists():files=Path(__file__).parent/'fixtures'
for filename in ['swift.life.json.sparse','dotnet.life.json.sparse']:
 data=json.loads((files/filename).read_text());legacy.validate_canvas_data(data)
 assert data['generation']==4 and data['rules']=={'survival_min':2,'survival_max':3,'birth_count':3}
 assert sum(map(sum,data['grid']))==5 and sum(map(sum,data['generation_zero_grid']))==5
with tempfile.TemporaryDirectory() as temporary:
 folder=Path(temporary)
 small=json.loads((files/'swift.life.json.sparse').read_text());small['name']='Visible v3 canvas'
 (folder/'small.life.json').write_text(json.dumps(small))
 big=dict(small,cols=101,rows=5,grid=[[0]*101 for _ in range(5)],generation_zero_grid=[[0]*101 for _ in range(5)],name='Hidden oversized canvas')
 (folder/'large.life.json').write_text(json.dumps(big))
 legacy.get_save_directory=lambda:temporary
 assert legacy.get_saved_canvas_names()==['Visible v3 canvas']
 try:legacy.validate_canvas_data(big)
 except ValueError:pass
 else:raise AssertionError('v2 accepted oversized file')
 assert small['grid']!=small['generation_zero_grid']
print('Original v2 validator accepts new small sparse documents; original saved-list filter quietly hides oversized canvases.')
