import land.nithi.life.*;
import java.util.Arrays;
public class PopulationJavaTest {
 static void check(boolean ok){if(!ok)throw new AssertionError("Population history regression");}
 static void values(LifeEngine e,int... expected){check(Arrays.equals(e.populationSeries(),expected));}
 public static void main(String[] args){LifeEngine e=new LifeEngine();e.clear();for(int x=1;x<=3;x++)e.set(x,1,true);e.set(9,9,true);values(e,4);e.step(true);values(e,4,3);e.checkpoint();e.set(20,20,true);values(e,4,4);e.step(true);values(e,4,4,3);e.undo();values(e,4,4);e.undo();values(e,4,3);e.redo();values(e,4,4);e.redo();values(e,4,4,3);e.back();values(e,4,4);e.restart();values(e,4);e.clear();values(e,0);e.undo();values(e,4);e.clear();for(int i=0;i<2100;i++)e.step(false);check(e.populationSeries().length==2048);for(int v:e.populationSeries())check(v==0);System.out.println("Java population graph: edits, Step, Back, Undo/Redo, reset and 2048 bound passed.");}
}
