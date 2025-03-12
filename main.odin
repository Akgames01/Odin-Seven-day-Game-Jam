package game

import "core:fmt"
import "core:strings"
import "core:mem"
import "core:os"
import "core:math"
import "core:encoding/json"
import rl"vendor:raylib"

LevelEdit :: struct {
    srcRect : [2]rl.Rectangle,
    destRect : [2]rl.Rectangle,
}

Button :: struct { 
    text : [dynamic]string,
    srcRect : [dynamic]rl.Rectangle, 
    destRect : [dynamic]rl.Rectangle, 
}
TextureData :: struct {
    assetName : [dynamic]string,
    sourceRects : [dynamic]rl.Rectangle,
}
LeveData :: struct {
    levelName : string, 
    objectName : [dynamic]string,
    renderGrid : [dynamic]rl.Vector2,
    sourceRect : [dynamic]rl.Rectangle, 
    destinationRect : [dynamic]rl.Rectangle,
}
levelData : [1]LeveData
LevelEditorAssets :: struct {
    objectName : [dynamic]string,
    sourceRect : [dynamic]rl.Rectangle, 
    destinationRect : [dynamic]rl.Rectangle,
}
levelEditorAsset : LevelEditorAssets
textureData : TextureData
editorObjectSelected : bool
editorObjectSelectedSrcRect : rl.Rectangle
editorObjectSelectedDestRect: rl.Rectangle
editorObjectSelectedName: string
editorObjectSelectedRenderGrid: rl.Vector2
levelObjectSelected : bool
levelObjectSelectedIndex : int
mainMenuButtons : Button
returnToMenuButton : Button
levelEditorObject : LevelEdit
inputTextBoxEnable : bool
inputTextBuilder : strings.Builder
textureAtlas : rl.Texture2D
isRunning : bool 
SCREEN_HEIGHT : int = 1080
SCREEN_WIDTH : int = 1920
backgroundColor : rl.Color = rl.BLACK
backgroundColorCopy : rl.Color = {100, 100, 170, 255}
currentScene : string = ""
previousScene : string = ""
playerSrc : rl.Rectangle
playerDestination : rl.Rectangle 
playerDirection : string
editorMode : bool 
camera : rl.Camera2D
frameCount : int 
movementSpeed : f32 = 400
toggleAlarm : bool = false
startAlarm : bool = false
endAlarm : bool = false
alarmAlpha : f32 = 0.0
playerUnderFakeWall : bool = false
previousPlayerPosition : rl.Vector2
levelCompleted : bool = false
Laser :: struct {
    laserOn : [dynamic]bool,
    laserType : [dynamic]string,
    destRect : [dynamic]rl.Rectangle,
    srcRect : [dynamic]rl.Rectangle,
    level : string,
}
lasers : [dynamic]Laser
update :: proc() {
    isRunning = !rl.WindowShouldClose()
    frameCount += 1
    if currentScene == "Main Menu" {
        mainMenuButtonHandler()
    }
    if strings.contains(currentScene, "Level") {
        if rl.IsKeyPressed(.F2) {
            editorMode = !editorMode
        }
        if editorMode {
            levelEditorObject.destRect[0].x = playerDestination.x + playerDestination.width*2 + 100
            levelEditorObject.destRect[0].y = playerDestination.y
            levelEditorObject.destRect[1].x = playerDestination.x + playerDestination.width*2 + 100
            levelEditorObject.destRect[1].y = playerDestination.y + levelEditorObject.destRect[0].height*2
            inputEditorTextBoxHandler()
            editorObjectSelectionHandler()
            levelObjectEditor()
            levelObjectRemover()
            adjustCameraZoom()
        }
        previousPlayerPosition = rl.Vector2{playerDestination.x, playerDestination.y}
        playerMovementY()
        playerCollisionCheckY()
        playerMovementX()
        playerCollisionCheckX()
        playerCollisionCheckFakeWall()
        trapCollisionCheck()
        setCameraTarget()
        laserTrigger()
        if rl.IsKeyPressed(.P) {
            toggleAlarm = !toggleAlarm
            startAlarm = !startAlarm
            alarmAlpha = 0
        }
        if startAlarm {
            startFade()
        }
        if endAlarm {
            endFade()
        }
        exitCollisionCheck()
    }
    if strings.contains(currentScene, "LevelComplete") {
        returnToMenuButtonHandler()
    }
    if currentScene == "Game Over" {
        returnToMenuButtonHandler()
    }
    sceneSwitcher()
}
inputEditorTextBoxHandler :: proc() {
    mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    if rl.CheckCollisionPointRec(mp, levelEditorObject.destRect[0]) && rl.IsMouseButtonPressed(.LEFT) {
        inputTextBoxEnable = true
    }
    else if !rl.CheckCollisionPointRec(mp, levelEditorObject.destRect[0]) && rl.IsMouseButtonPressed(.LEFT) {
        inputTextBoxEnable = false
    }
    if inputTextBoxEnable {
        if rl.IsKeyPressed(.BACKSPACE) {
            if strings.builder_len(inputTextBuilder) != 0 {
                strings.pop_rune(&inputTextBuilder)
            }
        }
        else {
            key := i32(rl.GetKeyPressed())
            if key >= 63 && key < 91 || key == 32 {
                if strings.builder_len(inputTextBuilder) == 0 {
                    strings.write_encoded_rune(&inputTextBuilder, rune(key), false)
                }
                else {
                    strings.write_encoded_rune(&inputTextBuilder, rune(key + 32), false)
                }
            }
        }
    }
}
//for editing purposes only 
sceneSwitcher :: proc() {
    if rl.IsKeyPressed(.ESCAPE) {
        currentScene = previousScene
        backgroundColor = backgroundColorCopy
    }
}
levelObjectRemover :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    for des,idx in levelData[chosenLevel].destinationRect {
        if !levelObjectSelected && rl.CheckCollisionPointRec(mp, des) && rl.IsMouseButtonPressed(.RIGHT) {
            ordered_remove(&levelData[chosenLevel].destinationRect, idx)
            ordered_remove(&levelData[chosenLevel].sourceRect, idx)
            ordered_remove(&levelData[chosenLevel].objectName, idx)
            ordered_remove(&levelData[chosenLevel].renderGrid, idx)
        }
    }
}
levelObjectEditor :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    for des,idx in levelData[chosenLevel].destinationRect {
        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        if rl.CheckCollisionPointRec(mp, des) && rl.IsKeyDown(.M) && rl.IsMouseButtonPressed(.MIDDLE) {
            levelObjectSelected = true
            levelObjectSelectedIndex = idx
        }
    }
    if levelObjectSelected {
        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].x = mp.x
        levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].y = mp.y
        if rl.IsKeyDown(.M) && rl.IsMouseButtonPressed(.LEFT) {
            levelObjectSelected = false
            // remX := i32(levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].x)%16
            // remY := i32(levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].y)%16
            // levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].x -= f32(remX)
            // levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].y -= f32(remY)
            levelObjectSelectedIndex = -1
        }
        if rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMove() > 0 && strings.contains(levelData[chosenLevel].objectName[levelObjectSelectedIndex], "Tile") {
            levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].y += 1
        }
        else if rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMove() < 0 && levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].y > 1 && strings.contains(levelData[chosenLevel].objectName[levelObjectSelectedIndex], "Tile")  {
            levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].y -= 1
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() > 0 && strings.contains(levelData[chosenLevel].objectName[levelObjectSelectedIndex], "Tile") {
            levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].x += 1
        }
        else if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() < 0 && levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].x > 1 && strings.contains(levelData[chosenLevel].objectName[levelObjectSelectedIndex], "Tile") {
            levelData[chosenLevel].renderGrid[levelObjectSelectedIndex].x -= 1
        }
        //for changing the respective scale -> width and height 
        if rl.IsKeyDown(.Q) && rl.GetMouseWheelMove() > 0 {
            levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].width = levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].width * 2.0
        }
        else if rl.IsKeyDown(.Q) && rl.GetMouseWheelMove() < 0 && levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].width > 16 {
            levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].width = levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].width * 0.5
        }
        if rl.IsKeyDown(.X) && rl.GetMouseWheelMove() > 0 {
            levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].height = levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].height * 2.0
        }
        else if rl.IsKeyDown(.X) && rl.GetMouseWheelMove() < 0 && levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].height > 16 {
            levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].height = levelData[chosenLevel].destinationRect[levelObjectSelectedIndex].height * 0.5
        }
    }
}
editorObjectSelectionHandler :: proc() {
    if rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMove() > 0 && strings.contains(editorObjectSelectedName, "Tile") {
        editorObjectSelectedRenderGrid.y += 1
    }
    else if rl.IsKeyDown(.LEFT_SHIFT) && rl.GetMouseWheelMove() < 0 && editorObjectSelectedRenderGrid.y > 1 && strings.contains(editorObjectSelectedName, "Tile")  {
        editorObjectSelectedRenderGrid.y -= 1
    }
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() > 0 && strings.contains(editorObjectSelectedName, "Tile") {
        editorObjectSelectedRenderGrid.x += 1
    }
    else if rl.IsKeyDown(.LEFT_CONTROL) && rl.GetMouseWheelMove() < 0 && editorObjectSelectedRenderGrid.x > 1 && strings.contains(editorObjectSelectedName, "Tile") {
        editorObjectSelectedRenderGrid.x -= 1
    }
    //for changing the respective scale -> width and height 
    if rl.IsKeyDown(.Q) && rl.GetMouseWheelMove() > 0 {
        editorObjectSelectedDestRect.width = editorObjectSelectedDestRect.width * 2.0
    }
    else if rl.IsKeyDown(.Q) && rl.GetMouseWheelMove() < 0 && editorObjectSelectedDestRect.width > 16 {
        editorObjectSelectedDestRect.width = editorObjectSelectedDestRect.width * 0.5
    }
    if rl.IsKeyDown(.X) && rl.GetMouseWheelMove() > 0 {
        editorObjectSelectedDestRect.height = editorObjectSelectedDestRect.height * 2.0
    }
    else if rl.IsKeyDown(.X) && rl.GetMouseWheelMove() < 0 && editorObjectSelectedDestRect.height > 16 {
        editorObjectSelectedDestRect.height = editorObjectSelectedDestRect.height * 0.5
    }
    for des,idx in levelEditorAsset.destinationRect {
        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        if rl.CheckCollisionPointRec(mp, des) && rl.IsMouseButtonPressed(.LEFT) {
            editorObjectSelected = true
            editorObjectSelectedDestRect = rl.Rectangle{des.x, des.y, des.width, des.height}
            editorObjectSelectedSrcRect = levelEditorAsset.sourceRect[idx]
            editorObjectSelectedName = levelEditorAsset.objectName[idx]
            editorObjectSelectedRenderGrid = {1,1}
        }
        if rl.IsMouseButtonPressed(.RIGHT) {
            editorObjectSelected = false
            editorObjectSelectedDestRect = rl.Rectangle{0,0,0,0}
            editorObjectSelectedSrcRect = rl.Rectangle{0,0,0,0}
            editorObjectSelectedName = ""
            editorObjectSelectedRenderGrid = rl.Vector2{0,0}
        }
    }
    if editorObjectSelected {
        mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        editorObjectSelectedDestRect.x = mp.x
        editorObjectSelectedDestRect.y = mp.y
        selectedLevel := getChosenLevel(currentScene)
        if rl.IsKeyDown(.M) && rl.IsMouseButtonPressed(.LEFT) {
            // remX := i32(editorObjectSelectedDestRect.x)%16
            // remY := i32(editorObjectSelectedDestRect.y)%16
            // editorObjectSelectedDestRect.x -= f32(remX)
            // editorObjectSelectedDestRect.y -= f32(remY)
            append(&levelData[selectedLevel].destinationRect, editorObjectSelectedDestRect)
            append(&levelData[selectedLevel].sourceRect, editorObjectSelectedSrcRect)
            append(&levelData[selectedLevel].objectName, editorObjectSelectedName)
            append(&levelData[selectedLevel].renderGrid, editorObjectSelectedRenderGrid)
            editorObjectSelected = false
            editorObjectSelectedDestRect = rl.Rectangle{0,0,0,0}
            editorObjectSelectedSrcRect = rl.Rectangle{0,0,0,0}
            editorObjectSelectedName = ""
            editorObjectSelectedRenderGrid = rl.Vector2{0,0}
        }
        
    }
}
playerMovementY :: proc() {
    dt := rl.GetFrameTime()
    if rl.IsKeyDown(.W) {
        playerDestination.y -= movementSpeed*dt
        playerDirection = "up"
    }
    if rl.IsKeyDown(.S) {
        playerDestination.y += movementSpeed*dt
        playerDirection = "down"
    }
}
playerMovementX :: proc() {
    dt := rl.GetFrameTime()
    if rl.IsKeyDown(.A) {
        playerDestination.x -= movementSpeed*dt
        playerDirection = "left"
    }
    if rl.IsKeyDown(.D) {
        playerDestination.x += movementSpeed*dt
        playerDirection = "right"
    }
}
playerCollisionCheckX :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    for des,idx in levelData[chosenLevel].destinationRect {
        if strings.contains(levelData[chosenLevel].objectName[idx], "Wall") && !strings.contains(levelData[chosenLevel].objectName[idx], "FakeWall") {
            for i in 0..<levelData[chosenLevel].renderGrid[idx].x {
                for j in 0..<levelData[chosenLevel].renderGrid[idx].y {
                    wallRect := rl.Rectangle{des.x + des.width*j, des.y + des.height*i, des.width, des.height}
                    colliderRect := rl.GetCollisionRec(playerDestination, wallRect)
                    if colliderRect.width != 0 {
                        directionSign : f32
                        playerRelative : rl.Vector2 = {playerDestination.x + playerDestination.width/2 - (wallRect.x + wallRect.width/2), playerDestination.y + playerDestination.height/2 - (wallRect.y + wallRect.height/2)}
                        if playerRelative.x < 0 {
                            directionSign = -1
                        }
                        else if playerRelative.x > 0 {
                            directionSign = 1
                        }
                        directionFix := colliderRect.width*directionSign
                        playerDestination.x += directionFix
                        break
                    }
                }
            }
        }
    }
}
playerCollisionCheckY :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    for des,idx in levelData[chosenLevel].destinationRect {
        if strings.contains(levelData[chosenLevel].objectName[idx], "Wall") && !strings.contains(levelData[chosenLevel].objectName[idx], "FakeWall") {
            for i in 0..<levelData[chosenLevel].renderGrid[idx].x {
                for j in 0..<levelData[chosenLevel].renderGrid[idx].y {
                    wallRect := rl.Rectangle{des.x + des.width*j, des.y + des.height*i, des.width, des.height}
                    colliderRect := rl.GetCollisionRec(playerDestination, wallRect)
                    if colliderRect.height != 0 {
                        directionSign : f32
                        playerRelative : rl.Vector2 = {playerDestination.x + playerDestination.width/2 - (wallRect.x + wallRect.width/2), playerDestination.y + playerDestination.height/2 - (wallRect.y + wallRect.height/2)}
                        if playerRelative.y < 0 {
                            directionSign = -1
                        }
                        else if playerRelative.y > 0 {
                            directionSign = 1
                        }
                        directionFix := colliderRect.height*directionSign
                        playerDestination.y += directionFix
                        break
                    }
                }
            }
        }
    }
}
playerCollisionCheckFakeWall :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    for des,idx in levelData[chosenLevel].destinationRect {
        if strings.contains(levelData[chosenLevel].objectName[idx], "FakeWall") {
            playerPoint := rl.Vector2{playerDestination.x + playerDestination.width/2, playerDestination.y + playerDestination.height}
            wallRect := rl.Rectangle{des.x , des.y , des.width*levelData[chosenLevel].renderGrid[idx].y*1.25,  des.height*levelData[chosenLevel].renderGrid[idx].x*1.25 }
            if rl.CheckCollisionPointRec(playerPoint, wallRect) {
                playerUnderFakeWall = true
                break
            }
            else {
                playerUnderFakeWall = false
            }
        }
    }
}
trapCollisionCheck :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    if frameCount%12 == 1 {
        for des,idx in levelData[chosenLevel].destinationRect {
            if strings.contains(levelData[chosenLevel].objectName[idx], "FloorTrapTile") {
                playerCentre := rl.Vector2{playerDestination.x + playerDestination.width/2, playerDestination.y + playerDestination.height/2}
                if rl.CheckCollisionPointRec(playerCentre, des) {
                    ordered_remove(&levelData[chosenLevel].destinationRect, idx)
                    ordered_remove(&levelData[chosenLevel].sourceRect, idx)
                    ordered_remove(&levelData[chosenLevel].objectName, idx)
                    ordered_remove(&levelData[chosenLevel].renderGrid, idx)
                    break
                }
            }
        }
    }
    else if frameCount%12 == 0 {
        for des,idx in levelData[chosenLevel].destinationRect {
            if strings.contains(levelData[chosenLevel].objectName[idx], "FloorTrapHole") {
                playerCentre := rl.Vector2{playerDestination.x + playerDestination.width/2, playerDestination.y + playerDestination.height/2}
                if rl.CheckCollisionPointRec(playerCentre, des) {
                    previousScene = currentScene
                    currentScene = "Game Over"
                    backgroundColor = rl.BLACK
                    camera.target = rl.Vector2{f32(SCREEN_WIDTH)/2, f32(SCREEN_HEIGHT)/2}
                }
            }
        }
    }
}
exitCollisionCheck :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    for des,idx in levelData[chosenLevel].destinationRect {
        if strings.contains(levelData[chosenLevel].objectName[idx], "ExitBanner") {
            playerCentre := rl.Vector2{playerDestination.x + playerDestination.width/2, playerDestination.y + playerDestination.height/2}
            if rl.CheckCollisionPointRec(playerCentre, des) {
                levelCompleted = true
                currentScene = "LevelComplete"
                camera.target = rl.Vector2{f32(SCREEN_WIDTH)/2, f32(SCREEN_HEIGHT)/2}
                break
            }
        }
    }
}
setCameraTarget :: proc() {
    lerpTime := f32(5.0)
    // currentTime := rl.GetFrameTime()
    // t := math.clamp(i32(currentTime/lerpTime), 0, 5)

    // Lerp camera target position
    camera.target = {playerDestination.x, playerDestination.y} //lerpVector2(previousPlayerPosition,  , f32(t))
    // if t >= 1 {
    //     currentTime = 0
    // }
    // camera.target = rl.Vector2{rl.Lerp(previousPlayerPosition.x, playerDestination.x, 5), rl.Lerp(previousPlayerPosition.y, playerDestination.y, 5)}
}
setDefaultCameraOffset :: proc() {
    camera.offset = {f32(SCREEN_WIDTH)/2, f32(SCREEN_HEIGHT)/2}
    camera.target = {0,0}
}
lerpVector2 :: proc(start : rl.Vector2, target : rl.Vector2, time : f32) -> rl.Vector2 {
    return rl.Vector2{rl.Lerp(start.x, target.x, time), rl.Lerp(start.y, target.y, time)}
}
adjustCameraZoom :: proc() {
    if rl.IsKeyDown(.Z) && rl.GetMouseWheelMove() > 0 {
        camera.zoom += 0.1
    }
    else if rl.IsKeyDown(.Z) && rl.GetMouseWheelMove() < 0 {
        camera.zoom -= 0.1
    }
}
laserTrigger :: proc() {
    chosenLevel := getChosenLevel(currentScene)
    //time := rl.GetFrameTime()
    for des,idx in lasers[chosenLevel].destRect {
        if frameCount % int(rl.GetMonitorRefreshRate(0)*8) == 1 {
            if lasers[chosenLevel].laserOn[idx] && strings.contains(lasers[chosenLevel].laserType[idx], "Vertical") {
                lasers[chosenLevel].laserOn[idx] = false
                lasers[chosenLevel].srcRect[idx].x = 400
                lasers[chosenLevel].srcRect[idx].y = 32
            }
            if lasers[chosenLevel].laserOn[idx] && !strings.contains(lasers[chosenLevel].laserType[idx], "Vertical") {
                lasers[chosenLevel].laserOn[idx] = false
                lasers[chosenLevel].srcRect[idx].x = 352
                lasers[chosenLevel].srcRect[idx].y = 32
            }
        }
        else if frameCount % int(rl.GetMonitorRefreshRate(0)*4) == 0 {
            if !lasers[chosenLevel].laserOn[idx] && strings.contains(lasers[chosenLevel].laserType[idx], "Vertical") {
                lasers[chosenLevel].laserOn[idx] = true
                lasers[chosenLevel].srcRect[idx].x = 416
                lasers[chosenLevel].srcRect[idx].y = 32
            }
            if !lasers[chosenLevel].laserOn[idx] && !strings.contains(lasers[chosenLevel].laserType[idx], "Vertical") {
                lasers[chosenLevel].laserOn[idx] = true
                lasers[chosenLevel].srcRect[idx].x = 352
                lasers[chosenLevel].srcRect[idx].y = 48
            }
        } 
        if lasers[chosenLevel].laserOn[idx] && rl.CheckCollisionPointRec({playerDestination.x + playerDestination.width/2, playerDestination.y + playerDestination.height/2}, lasers[chosenLevel].destRect[idx]) {
            //fmt.print("alarm triggered! \n")
            toggleAlarm = true
            startAlarm = true
            alarmAlpha = 0
        }
    }
}
mainMenuButtonHandler :: proc() {
    for sr,idx in mainMenuButtons.srcRect {
        mousePointer := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
        if rl.CheckCollisionPointRec(mousePointer, mainMenuButtons.destRect[idx]) && rl.IsMouseButtonPressed(.LEFT) {
            mainMenuButtons.srcRect[idx].x = 272
            mainMenuButtons.srcRect[idx].y = 16
            if mainMenuButtons.text[idx] == "Exit" {
                isRunning = !isRunning
            }
            else if mainMenuButtons.text[idx] == "Start"{
                previousScene = currentScene
                currentScene = "Level1"
                //initialize level state and player state 
            }
        }
        else if rl.CheckCollisionPointRec(mousePointer, mainMenuButtons.destRect[idx]) {
            mainMenuButtons.srcRect[idx].x = 240
            mainMenuButtons.srcRect[idx].y = 16
        }
        else {
            mainMenuButtons.srcRect[idx].x = 208
            mainMenuButtons.srcRect[idx].y = 16
        }
    }
}
getChosenLevel :: proc(levelString : string) -> int {
    if levelString == "Level1" {
        return 0
    }
    else if levelString == "Level2" {
        return 1
    }
    else if levelString == "Level3" {
        return 2
    }
    else if levelString == "Level4" {
        return 3
    }
    return 0
}
startFade :: proc() {
    time := rl.GetFrameTime()
    if alarmAlpha < 1  {
        alarmAlpha += time/(100*time)
    }
    else {
        startAlarm = false
        endAlarm = true
    }
}
endFade :: proc() {
    time := rl.GetFrameTime()
    if alarmAlpha > 0  {
        alarmAlpha -= time/(100*time)
    }
    else {
        endAlarm = false
        startAlarm = true
    }
}
drawAlarmRec :: proc() {
    cameraRect := rl.Rectangle{playerDestination.x - f32(SCREEN_WIDTH)/2, playerDestination.y - f32(SCREEN_HEIGHT)/2, f32(SCREEN_WIDTH), f32(SCREEN_HEIGHT)}
    color := rl.Fade(rl.RED, alarmAlpha)
    rl.DrawRectanglePro(cameraRect, {0,0}, 0.0, color)
}
returnToMenuButtonHandler :: proc() {
    mp := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    for des,idx in returnToMenuButton.destRect {
        returnToMenuButton.destRect[idx].x = camera.offset.x*2 - returnToMenuButton.destRect[idx].width - 100
        returnToMenuButton.destRect[idx].y = camera.offset.y*2 - returnToMenuButton.destRect[idx].height - 200
        if rl.CheckCollisionPointRec(mp, des) && rl.IsMouseButtonPressed(.LEFT) {
            returnToMenuButton.srcRect[idx].x = 336
            returnToMenuButton.srcRect[idx].y = 160
            currentScene = "Main Menu"
            levelCompleted = false
            playerDestination.x = 0
            playerDestination.y = 0
            setDefaultCameraOffset()
        }
        else if rl.CheckCollisionPointRec(mp, des) {
            returnToMenuButton.srcRect[idx].x = 304
            returnToMenuButton.srcRect[idx].y = 160
        }
        else {
            returnToMenuButton.srcRect[idx].x = 272
            returnToMenuButton.srcRect[idx].y = 160
        }
    }
}
drawScene :: proc() {
    if currentScene == "Main Menu" {
        camera.target = {f32(SCREEN_WIDTH)/2, f32(SCREEN_HEIGHT)/2}
        for bt,idx in mainMenuButtons.destRect {
            rl.DrawTexturePro(textureAtlas, mainMenuButtons.srcRect[idx], bt, {0,0}, 0.0, rl.WHITE)
            header := strings.clone_to_cstring(mainMenuButtons.text[idx])
            rl.DrawText(header,i32(bt.x + bt.width/4), i32(bt.y + bt.height/3), 20, rl.WHITE)
            delete(header)
        }
    }
    if currentScene == "Puzzle Select" {
        //
    }
    if strings.contains(currentScene, "Level") && !levelCompleted {
        //rendering the respective objects 
        chosenLevel := getChosenLevel(currentScene)
        if rl.IsKeyPressed(.O) {
            fmt.print("current level data object : ", levelData[chosenLevel], "\n")
        }
        for sr,idx in levelData[chosenLevel].sourceRect {
            if (strings.contains(levelData[chosenLevel].objectName[idx], "Tile") || strings.contains(levelData[chosenLevel].objectName[idx], "FloorTrapHole")) && !strings.contains(levelData[chosenLevel].objectName[idx], "FakeWallTopTile"){
                for i in 0..<i32(levelData[chosenLevel].renderGrid[idx].x) {
                    for j in 0..<i32(levelData[chosenLevel].renderGrid[idx].y) {
                        destRect := rl.Rectangle{levelData[chosenLevel].destinationRect[idx].x + levelData[chosenLevel].destinationRect[idx].width*f32(j), levelData[chosenLevel].destinationRect[idx].y + levelData[chosenLevel].destinationRect[idx].height*f32(i), levelData[chosenLevel].destinationRect[idx].width, levelData[chosenLevel].destinationRect[idx].height}
                        rl.DrawTexturePro(textureAtlas, sr, destRect, {0,0}, 0.0, rl.WHITE)
                    }
                }
            }
        }
        //a render queue system for the z sorting based on relative coordinates 
        rl.DrawRectangle(i32(playerDestination.x), i32(playerDestination.y), i32(playerDestination.width), i32(playerDestination.height), rl.RED)
        for sr,idx in levelData[chosenLevel].sourceRect {
            if strings.contains(levelData[chosenLevel].objectName[idx], "FakeWallTopTile"){
                for i in 0..<i32(levelData[chosenLevel].renderGrid[idx].x) {
                    for j in 0..<i32(levelData[chosenLevel].renderGrid[idx].y) {
                        destRect := rl.Rectangle{levelData[chosenLevel].destinationRect[idx].x + levelData[chosenLevel].destinationRect[idx].width*f32(j), levelData[chosenLevel].destinationRect[idx].y + levelData[chosenLevel].destinationRect[idx].height*f32(i), levelData[chosenLevel].destinationRect[idx].width, levelData[chosenLevel].destinationRect[idx].height}
                        if playerUnderFakeWall {
                            rl.DrawTexturePro(textureAtlas, sr, destRect, {0,0}, 0.0, rl.Color{255,255,255,100})
                        }
                        else {
                            rl.DrawTexturePro(textureAtlas, sr, destRect, {0,0}, 0.0, rl.WHITE)
                        }
                    }
                }
            }
        }
        for sr,idx in levelData[chosenLevel].sourceRect {
            if !strings.contains(levelData[chosenLevel].objectName[idx], "Tile") && !strings.contains(levelData[chosenLevel].objectName[idx], "FloorTrapHole") && !strings.contains(levelData[chosenLevel].objectName[idx], "Laser") {
                rl.DrawTexturePro(textureAtlas, sr, levelData[chosenLevel].destinationRect[idx], {0,0}, 0.0, rl.WHITE)
            }
        }
        for des,idx in lasers[chosenLevel].destRect {
            rl.DrawTexturePro(textureAtlas, lasers[chosenLevel].srcRect[idx], des, {0,0}, 0.0, rl.WHITE)
        }
        if toggleAlarm {
            drawAlarmRec()
        }
        if editorMode {
            for ob,idx in levelEditorObject.destRect {
                rl.DrawTexturePro(textureAtlas, levelEditorObject.srcRect[idx], ob, {0,0}, 0.0, rl.WHITE)
            }
            Temp_width : f32 = 0
            Temp_height : f32 = 0
            heightAdder : f32 = 0
            displayString : string = strings.to_string(inputTextBuilder) 
            if inputTextBoxEnable {
                convertedString := strings.clone_to_cstring(displayString)
                rl.DrawText(convertedString, i32(levelEditorObject.destRect[0].x) + 10, i32(levelEditorObject.destRect[0].y) + 5, 25, rl.WHITE)
                delete(convertedString)
            }
            for sr,idx in levelEditorAsset.sourceRect {
                if strings.contains(levelEditorAsset.objectName[idx], displayString) {
                    if Temp_width > levelEditorObject.destRect[1].width {
                        Temp_width = 0
                        heightAdder += Temp_height
                        Temp_height = 0
                    }
                    if Temp_width == 0 {
                        levelEditorAsset.destinationRect[idx].x = levelEditorObject.destRect[1].x + 10
                        levelEditorAsset.destinationRect[idx].y = levelEditorObject.destRect[1].y + heightAdder + 10
                        Temp_width += levelEditorAsset.destinationRect[idx].width + 10
                        Temp_height = max(Temp_height, levelEditorAsset.destinationRect[idx].height)
                    }
                    else {
                        levelEditorAsset.destinationRect[idx].x = levelEditorObject.destRect[1].x + Temp_width + 10
                        levelEditorAsset.destinationRect[idx].y = levelEditorObject.destRect[1].y + heightAdder + 10
                        Temp_width += levelEditorAsset.destinationRect[idx].width + 10
                        Temp_height = max(Temp_height, levelEditorAsset.destinationRect[idx].height)
                    }
                    rl.DrawTexturePro(textureAtlas, sr, levelEditorAsset.destinationRect[idx], {0,0}, 0.0, rl.WHITE)
                }
            }
            if editorObjectSelected {
                if strings.contains(editorObjectSelectedName, "Tile") {
                    for i in 0..<i32(editorObjectSelectedRenderGrid.x) {
                        for j in 0..<i32(editorObjectSelectedRenderGrid.y) {
                            destRect := rl.Rectangle{editorObjectSelectedDestRect.x + editorObjectSelectedDestRect.width*f32(j), editorObjectSelectedDestRect.y + editorObjectSelectedDestRect.height*f32(i), editorObjectSelectedDestRect.width, editorObjectSelectedDestRect.height}
                            rl.DrawTexturePro(textureAtlas, editorObjectSelectedSrcRect, destRect, {0,0}, 0.0, rl.WHITE)
                        }
                    }
                }
                else {
                    rl.DrawTexturePro(textureAtlas, editorObjectSelectedSrcRect, editorObjectSelectedDestRect, {0,0}, 0.0, rl.WHITE)
                }
            }
        }
    }
    if strings.contains(currentScene, "LevelComplete") && levelCompleted {
        rl.DrawText("Level Completed!", i32(f32(SCREEN_WIDTH)/2.5),i32(f32(SCREEN_HEIGHT)/4), 50, rl.WHITE)
        alarmRaised : bool = false
        if toggleAlarm {
            alarmRaised = true
        }
        if alarmRaised {
            rl.DrawText("No Alarm Raised : ", i32(f32(SCREEN_WIDTH)/2.5),i32(f32(SCREEN_HEIGHT)/4) + 50, 50, rl.WHITE)
            srcRect := rl.Rectangle{320,135,9,9}
            destRect := rl.Rectangle{f32(SCREEN_WIDTH)/2.5 + 250,f32(SCREEN_HEIGHT)/4 + 50,45,45}
            rl.DrawTexturePro(textureAtlas, srcRect, destRect, {0,0}, 0.0, rl.WHITE)
        }
        else {
            rl.DrawText("No Alarm Raised : ", i32(f32(SCREEN_WIDTH)/2.5),i32(f32(SCREEN_HEIGHT)/4) + 50, 50, rl.WHITE)
            srcRect := rl.Rectangle{304,135,9,9}
            destRect := rl.Rectangle{f32(SCREEN_WIDTH)/2.5 + 450,f32(SCREEN_HEIGHT)/4 + 50,45,45}
            rl.DrawTexturePro(textureAtlas, srcRect, destRect, {0,0}, 0.0, rl.WHITE)
        }
        
        for des,idx in returnToMenuButton.destRect {
            rl.DrawTexturePro(textureAtlas, returnToMenuButton.srcRect[idx], des, {0,0}, 0.0, rl.WHITE)
        }
    }
    if currentScene == "Game Over" {
        rl.DrawText("Game Over!", i32(camera.offset.x),i32(camera.offset.y - 50), 50, rl.WHITE)
        for des,idx in returnToMenuButton.destRect {
            rl.DrawTexturePro(textureAtlas, returnToMenuButton.srcRect[idx], des, {0,0}, 0.0, rl.WHITE)
        }
    }
}
render :: proc() {
    rl.BeginDrawing()
    rl.BeginMode2D(camera)
    rl.ClearBackground(backgroundColor)
    drawScene()
    rl.DrawFPS(i32(playerDestination.x + 500), i32(playerDestination.y - 400))
    rl.EndMode2D()
    rl.EndDrawing()
}

init :: proc() {
    rl.InitWindow(i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), "Puzzle Game")
    rl.InitAudioDevice()
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))
    rl.SetExitKey(.KP_0)
    isRunning = true
    inputTextBoxEnable = false 
    currentScene = "Main Menu"
    textureAtlas = rl.LoadTexture("Assets/SevenDayJamUI.png")
    setTextureDataValues()
    mainMenuButtonDestRects : [2]rl.Rectangle = {
        {f32(SCREEN_WIDTH)/1.8 - 128, f32(SCREEN_HEIGHT)/1.5 + 20, 128, 64},
        {f32(SCREEN_WIDTH)/1.8 - 128, f32(SCREEN_HEIGHT)/1.5 + 128, 128, 64},
    }
    returnMenuButtonDestRect : rl.Rectangle = {f32(SCREEN_WIDTH) - 128, f32(SCREEN_HEIGHT) - 20, 128, 64}
    nameIndex : int
    returnButtonIndex : int
    for te,idx in textureData.sourceRects {
        if textureData.assetName[idx] == "mainMenuButtons" {
            nameIndex = idx
        }
        else if textureData.assetName[idx] == "ReturnToMenuButton" {
            returnButtonIndex = idx
        }
        else if strings.contains(textureData.assetName[idx], "levelEditorInputBox") {
            levelEditorObject.srcRect[0] = te
            levelEditorObject.destRect[0] = {0, 0, te.width*2, te.height*2}
        }
        else if strings.contains(textureData.assetName[idx], "levelEditorTextureBox") {
            levelEditorObject.srcRect[1] = te
            levelEditorObject.destRect[1] = {0, 0, te.width*2, te.height*2}
        }
        else {
            append(&levelEditorAsset.objectName, textureData.assetName[idx])
            append(&levelEditorAsset.sourceRect, textureData.sourceRects[idx])
            append(&levelEditorAsset.destinationRect, rl.Rectangle{0,0,textureData.sourceRects[idx].width, textureData.sourceRects[idx].height})
        }
    }
    append(&mainMenuButtons.srcRect, textureData.sourceRects[nameIndex])
    append(&mainMenuButtons.srcRect, textureData.sourceRects[nameIndex])
    append(&mainMenuButtons.text, "Start")
    append(&mainMenuButtons.text, "Exit")
    for brect,idx in mainMenuButtonDestRects {
        append(&mainMenuButtons.destRect,brect)
    }
    append(&returnToMenuButton.srcRect, textureData.sourceRects[returnButtonIndex])
    append(&returnToMenuButton.text, "")
    append(&returnToMenuButton.destRect, returnMenuButtonDestRect)
    // fmt.print("main menu buttons object : ", mainMenuButtons, "\n")
    editorMode = false
    playerSrc = {0,0,0,0}
    playerDestination = {0,0,32,32}
    camera = rl.Camera2D{rl.Vector2{f32(SCREEN_WIDTH/2), f32(SCREEN_HEIGHT/2)}, rl.Vector2{playerDestination.x - (playerDestination.width/2),playerDestination.y - (playerDestination.height/2)}, 0.0, 1.0}
    camera.zoom += 0.1
    editorMode = false
    editorObjectSelected = false
    if level_data,ok := os.read_entire_file("level.json", context.temp_allocator); ok {
        if json.unmarshal(level_data, &levelData) != nil {
            fmt.print("json unmarshall unsuccessful")
            levelData[0].levelName = "Level1"
        }
        for lvl,idx in levelData {
            tempLaserObj : Laser
            for des,id in levelData[idx].destinationRect {
                if strings.contains(levelData[idx].objectName[id], "Laser") {
                    append(&tempLaserObj.destRect, des)
                    append(&tempLaserObj.laserOn, true)
                    append(&tempLaserObj.laserType, levelData[idx].objectName[id])
                    append(&tempLaserObj.srcRect, levelData[idx].sourceRect[id])
                }
            }
            tempLaserObj.level = levelData[idx].levelName
            append(&lasers, tempLaserObj)
        }
        fmt.print("laser Object : ", lasers, "\n")
    }
    else {
        fmt.print("json unmarshall unsuccessful")
        levelData[0].levelName = "Level1"
    }
    frameCount = 0
}

quit :: proc() {
    rl.UnloadTexture(textureAtlas)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

main :: proc() {
    track : mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        for _,entry in track.allocation_map {
            fmt.eprintf("%v leaked %v bytes \n", entry.location, entry.size)
        }
        for entry in track.bad_free_array {
            fmt.eprintf("%v bad free \n ", entry.location)
        }
        mem.tracking_allocator_destroy(&track)
    }
    init()

    for isRunning {
        update()
        render()
    }
    quit()
    if editorMode {
        if level_data, err:= json.marshal(levelData, allocator = context.temp_allocator); err == nil {
            os.write_entire_file("level.json", level_data)
        } 
    }
    delete(mainMenuButtons.destRect)
    delete(mainMenuButtons.srcRect)
    delete(mainMenuButtons.text)
    delete(levelEditorAsset.destinationRect)
    delete(levelEditorAsset.sourceRect)
    delete(levelEditorAsset.objectName)
}

setTextureDataValues :: proc() { 
    assetNames :[20]string = {
        "levelEditorInputBox",
        "levelEditorTextureBox",
        "mainMenuButtons",
        "FloorTile",
        "WallTile",
        "WallTopTileLeftEnd",
        "WallTopTileRightEnd",
        "WallTopTile",
        "FloorTrapTile",
        "FloorTrapHole",
        "RedLaser",
        "RedLaserVertical",
        "RedLaser",
        "RedLaserVertical",
        "ExitBanner",
        "ExitNeonLight",
        "FakeWallTopTileLeftEnd",
        "FakeWallTopTileRightEnd",
        "FakeWallTopTile",
        "ReturnToMenuButton",
    }
    srcRects : [20]rl.Rectangle = {
        {16,144,80,16},
        {16,16,160,112},
        {208,16,32,16},
        {240,48,32,32},
        {272,48,32,32},
        {240,96,16,16},
        {272,96,16,16},
        {256,96,16,16},
        {304,48,32,32},
        {304,80,32,32},
        {352,48,48,16},
        {416,32,16,48},
        {352,64,48,16},
        {432,32,16,48},
        {416,96,64,32},
        {496,96,64,32},
        {240,128,16,16},
        {272,128,16,16},
        {256,128,16,16},
        {272,16,32,16},
        
    }
    for an,idx in assetNames {
        append(&textureData.assetName, an)
        append(&textureData.sourceRects, srcRects[idx])
    }
    // levelEditorAsset
}