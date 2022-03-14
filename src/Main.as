void Main() {
    CreateBlockItems();
}

Import::Library@ lib = null;
Import::Function@ clickFun = null;
Import::Function@ mousePosFun = null;
Import::Function@ justClickFun = null;

// todo exclude non native blocks! (magnets, edited blocks)

int totalBlocks = 2360;
int count = 0;
int screenWidth = 1;
int screenHeight = 1;

void CreateBlockItems() {
    @lib = GetZippedLibrary("lib/libclick.dll");
    if(lib !is null) {
        @clickFun = lib.GetFunction("clickPos");
        @justClickFun = lib.GetFunction("click");
        @mousePosFun = lib.GetFunction("moveMouse");
    }

    screenHeight = Draw::GetHeight();
    screenWidth = Draw::GetWidth();

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    auto inventory = pmt.Inventory;

    // ClearMap();

    auto blocksNode = cast<CGameCtnArticleNodeDirectory@>(inventory.RootNodes[0]);
    totalBlocks = CountBlocks(blocksNode);
    ExploreNode(blocksNode);
}

void ExploreNode(CGameCtnArticleNodeDirectory@ parentNode, string folder = "") {
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            ExploreNode(cast<CGameCtnArticleNodeDirectory@>(node), folder + node.Name + '/');
        } else {
            auto ana = cast<CGameCtnArticleNodeArticle@>(node);
            if(ana.Article is null || ana.Article.IdName.ToLower().EndsWith("customblock")) {
                warn("Block: " + ana.Name + " is not nadeo, skipping");
                continue;
            }
            string itemLoc = 'Nadeo/' + folder + ana.Name + '.Item.Gbx';
            count++;
            auto fullItemPath = IO::FromUserGameFolder("Items/" + itemLoc);
            if(IO::FileExists(fullItemPath)) {
                print("item: " + itemLoc + ", already exists!");
                // MyYield();
            } else {
                auto block = cast<CGameCtnBlockInfo@>(ana.Article.LoadedNod);
                if(block is null) {
                    warn("Block " + ana.Name + " is null!");
                    continue;
                }
                if(string(block.Name).ToLower().Contains("water")) {
                    warn("Water can't be converted!");
                    continue;
                }
                print("Converting block: " + block.Name + " " + count + " / " + totalBlocks);
                ConvertBlockToItem(block, itemLoc);
            }
        }
    }
}

int2 iconButton = int2(594, 557);
int2 iconDirectionButton = int2(1311, 736);

void ConvertBlockToItem(CGameCtnBlockInfo@ block, string desiredItemLocation) {
    // Click screen at position to enter "create new item" UI
    auto xClick = screenWidth / 2;
    auto yClick = screenHeight / 2;

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorCommon@>(app.Editor);
    auto pmt = editor.PluginMapType;
    auto placeLocation = int3(20, 15, 20);
    MyYield();
    pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
    MyYield();
    @pmt.CursorBlockModel = block;
    int nBlocks = pmt.Blocks.Length;
    while(nBlocks == pmt.Blocks.Length) {
        clickFun.Call(true, xClick, yClick);
        MyYield();
    }
    // pmt.PlaceBlock_NoDestruction(block, placeLocation, CGameEditorPluginMap::ECardinalDirections::North);
    editor.ButtonItemCreateFromBlockModeOnClick();
    MyYield();
    while(cast<CGameEditorItem>(app.Editor) is null) {
        @editor = cast<CGameCtnEditorCommon@>(app.Editor);
        if(editor !is null && editor.PickedBlock !is null && editor.PickedBlock.BlockInfo.IdName == block.IdName) {
            justClickFun.Call(true);
        }
        MyYield();
    }
    auto editorItem = cast<CGameEditorItem@>(app.Editor);
    editorItem.PlacementParamGridHorizontalSize = 32;
    editorItem.PlacementParamGridVerticalSize = 8;
    editorItem.PlacementParamFlyStep = 8;

    ClickPos(iconButton);
    MyYield();
    ClickPos(iconDirectionButton);
    MyYield();

    editorItem.FileSaveAs();
    
    MyYield();
    
    MyYield();
    app.BasicDialogs.String = desiredItemLocation;
    
    MyYield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield();
    app.BasicDialogs.DialogSaveAs_OnValidate();
    
    MyYield();
    cast<CGameEditorItem>(app.Editor).Exit();

    while(cast<CGameCtnEditorCommon@>(app.Editor) is null) {
        MyYield();
    }
    @editor = cast<CGameCtnEditorCommon@>(app.Editor);
    @pmt = editor.PluginMapType;
    pmt.Undo();
}

void ClickPos(int2 pos) {
    int x = int(float(pos.x) / 2560. * screenWidth);
    int y = int(float(pos.y) / 1440. * screenHeight);
    clickFun.Call(true, x, y);
}

void MyYield() {
    yield();
}

Import::Library@ GetZippedLibrary(const string &in relativeDllPath) {
    bool preventCache = false;

    auto parts = relativeDllPath.Split("/");
    string fileName = parts[parts.Length - 1];
    const string baseFolder = IO::FromDataFolder('');
    const string dllFolder = baseFolder + 'lib/';
    const string localDllFile = dllFolder + fileName;

    if(!IO::FolderExists(dllFolder)) {
        IO::CreateFolder(dllFolder);
    }

    if(preventCache || !IO::FileExists(localDllFile)) {
        try {
            IO::FileSource zippedDll(relativeDllPath);
            auto buffer = zippedDll.Read(zippedDll.Size());
            IO::File toItem(localDllFile, IO::FileMode::Write);
            toItem.Write(buffer);
            toItem.Close();
        } catch {
            return null;
        }
    }

    return Import::GetLibrary(localDllFile);
}


int CountBlocks(CGameCtnArticleNodeDirectory@ parentNode) {
    int count = 0;
    for(uint i = 0; i < parentNode.ChildNodes.Length; i++) {
        auto node = parentNode.ChildNodes[i];
        if(node.IsDirectory) {
            count += CountBlocks(cast<CGameCtnArticleNodeDirectory@>(node));
        } else {
            count++;
        }
    }
    return count;
}

void ClearMap() {
    auto editor = Editor();
    if(editor is null) return;    
    editor.PluginMapType.RemoveAllBlocks();
    // there may be items left in the map, remove as follows:
    if(editor.Challenge.AnchoredObjects.Length > 0) {
        auto placeMode = editor.PluginMapType.PlaceMode;
        CutMap();
        editor.PluginMapType.PlaceMode = placeMode;
    }
}

bool CutMap() {
    auto editor = Editor();
    if(editor is null) return false;
    editor.PluginMapType.CopyPaste_SelectAll();
    if(editor.PluginMapType.CopyPaste_GetSelectedCoordsCount() != 0) {
        editor.PluginMapType.CopyPaste_Cut();
        return true;
    }
    return false;
}

CGameCtnEditorCommon@ Editor() {
    auto app = GetApp();
    return cast<CGameCtnEditorCommon@>(app.Editor);
}