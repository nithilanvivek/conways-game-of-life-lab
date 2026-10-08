package land.nithi.conwaylifelab;

import land.nithi.shared.OfflineWebActivity;

public final class MainActivity extends OfflineWebActivity {
    @Override protected String folderPreferenceKey() { return "ConwayLifeLab.dataFolder.v1"; }
    @Override protected String fileSuffix() { return ".life.json"; }
}
