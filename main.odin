package game

import "core:fmt"
import "core:strings"
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
textureData : TextureData
mainMenuButtons : Button
levelEditorObject : LevelEdit
inputTextBoxEnable : bool
inputTextBuilder : strings.Builder
textureAtlas : rl.Texture2D
isRunning : bool 
SCREEN_HEIGHT : int = 1080
SCREEN_WIDTH : int = 1920
backgroundColor : rl.Color = {100, 100, 170, 255}
currentScene : string = ""
playerSrc : rl.Rectangle
playerDestination : rl.Rectangle 
editorMode : bool 
camera : rl.Camera2D
movementSpeed : f32 = 400
update :: proc() {
    isRunning = !rl.WindowShouldClose()
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
        }
        playerMovement()
    }
}
playerMovement :: proc() {
    dt := rl.GetFrameTime()
    if rl.IsKeyDown(.A) {
        playerDestination.x -= movementSpeed*dt
    }
    if rl.IsKeyDown(.W) {
        playerDestination.y -= movementSpeed*dt
    }
    if rl.IsKeyDown(.S) {
        playerDestination.y += movementSpeed*dt
    }
    if rl.IsKeyDown(.D) {
        playerDestination.x += movementSpeed*dt
    }
}
mainMenuButtonHandler :: proc() {
    for sr,idx in mainMenuButtons.srcRect {
        mousePointer := rl.GetMousePosition()
        if rl.CheckCollisionPointRec(mousePointer, mainMenuButtons.destRect[idx]) && rl.IsMouseButtonPressed(.LEFT) {
            mainMenuButtons.srcRect[idx].x = 272
            mainMenuButtons.srcRect[idx].y = 16
            if mainMenuButtons.text[idx] == "Exit" {
                isRunning = !isRunning
            }
            else if mainMenuButtons.text[idx] == "Start"{
                currentScene = "Level1"
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
drawScene :: proc() {
    if currentScene == "Main Menu" {
        camera.target = {f32(SCREEN_WIDTH)/2, f32(SCREEN_HEIGHT)/2}
        for bt,idx in mainMenuButtons.destRect {
            rl.DrawTexturePro(textureAtlas, mainMenuButtons.srcRect[idx], bt, {0,0}, 0.0, rl.WHITE)
            header := strings.clone_to_cstring(mainMenuButtons.text[idx])
            rl.DrawText(header,i32(bt.x + bt.width/4), i32(bt.y + bt.height/3), 20, rl.WHITE)
        }
    }
    if currentScene == "Puzzle Select" {
        //
    }
    if strings.contains(currentScene, "Level") {
        rl.DrawRectangle(i32(playerDestination.x), i32(playerDestination.y), 30, 30, rl.RED)
        if editorMode {
            for ob,idx in levelEditorObject.destRect {
                rl.DrawTexturePro(textureAtlas, levelEditorObject.srcRect[idx], ob, {0,0}, 0.0, rl.WHITE)
            }
        }
    }
}
render :: proc() {
    rl.BeginDrawing()
    rl.BeginMode2D(camera)
    rl.ClearBackground(backgroundColor)
    drawScene()
    rl.EndMode2D()
    rl.EndDrawing()
}

init :: proc() {
    rl.InitWindow(i32(SCREEN_WIDTH), i32(SCREEN_HEIGHT), "Puzzle Game")
    rl.InitAudioDevice()
    isRunning = true
    inputTextBoxEnable = false 
    currentScene = "Main Menu"
    textureAtlas = rl.LoadTexture("Assets/SevenDayJamUI.png")
    setTextureDataValues()
    mainMenuButtonDestRects : [2]rl.Rectangle = {
        {f32(SCREEN_WIDTH)/1.8 - 128, f32(SCREEN_HEIGHT)/1.5 + 20, 128, 64},
        {f32(SCREEN_WIDTH)/1.8 - 128, f32(SCREEN_HEIGHT)/1.5 + 128, 128, 64},
    }
    nameIndex : int
    for te,idx in textureData.sourceRects {
        if textureData.assetName[idx] == "mainMenuButtons" {
            nameIndex = idx
            break
        }
        if strings.contains(textureData.assetName[idx], "levelEditorInputBox") {
            levelEditorObject.srcRect[0] = te
            levelEditorObject.destRect[0] = {0, 0, te.width*2, te.height*2}
        }
        if strings.contains(textureData.assetName[idx], "levelEditorTextureBox") {
            levelEditorObject.srcRect[1] = te
            levelEditorObject.destRect[1] = {0, 0, te.width*2, te.height*2}
        }
    }
    append(&mainMenuButtons.srcRect, textureData.sourceRects[nameIndex])
    append(&mainMenuButtons.srcRect, textureData.sourceRects[nameIndex])
    append(&mainMenuButtons.text, "Start")
    append(&mainMenuButtons.text, "Exit")
    for brect,idx in mainMenuButtonDestRects {
        append(&mainMenuButtons.destRect,brect)
    }
    // fmt.print("main menu buttons object : ", mainMenuButtons, "\n")
    editorMode = false
    playerSrc = {0,0,0,0}
    playerDestination = {0,0,0,0}
    camera = rl.Camera2D{rl.Vector2{f32(SCREEN_WIDTH/2), f32(SCREEN_HEIGHT/2)}, rl.Vector2{playerDestination.x - (playerDestination.width/2),playerDestination.y - (playerDestination.height/2)}, 0.0, 1.0}
    

}

quit :: proc() {
    rl.UnloadTexture(textureAtlas)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

main :: proc() {
    init()

    for isRunning {
        update()
        render()
    }
    quit()

    delete(mainMenuButtons.destRect)
    delete(mainMenuButtons.srcRect)
    delete(mainMenuButtons.text)
}

setTextureDataValues :: proc() { 
    assetNames :[3]string = {
        "levelEditorInputBox",
        "levelEditorTextureBox",
        "mainMenuButtons",
    }
    srcRects : [3]rl.Rectangle = {
        {16,144,80,16},
        {16,16,160,112},
        {208,16,32,16},
    }
    for an,idx in assetNames {
        append(&textureData.assetName, an)
        append(&textureData.sourceRects, srcRects[idx])
    }
}