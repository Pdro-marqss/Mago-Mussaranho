// @TODO
// TROCAR NOME DO PROJETO E SUBIR NO GITHUB

package main

import "vendor:raylib"
import "core:fmt"
import "core:os"
import "core:strconv"


GameState :: enum {
    Main_Menu,
    Playing,
    Paused,
    Game_Over
}

SessionData :: struct {
    score: f32,
    high_score: f32,
    deaths: int,
    game_time: f32,
    enemy_spawn_timer: f32,
    current_spawn_rate: f32,
    current_enemy_speed: f32,
    center_zone: ConquestZone,
    points_fade_text_timer: f32,
    points_fade_text_alpha: f32,
    intro_fade_timer: f32,
}

Player :: struct {
    pos: raylib.Vector2,
    speed: f32,
    radius: f32
}

Enemy :: struct {
    pos: raylib.Vector2,
    vel: raylib.Vector2,
    radius: f32
}

ConquestZone :: struct {
    pos: raylib.Vector2,
    radius: f32,
    active: bool,
    progress: f32
}


player: Player
enemies: [dynamic]Enemy
session_game_data: SessionData
game_state: GameState

INTRO_FADE_DURATION :: 4.0

// Reset sessionData 
reset_session :: proc() {
    screen_width := f32(raylib.GetScreenWidth())
    screen_height := f32(raylib.GetScreenHeight())

    session_game_data.score = 0
    session_game_data.game_time = 0
    session_game_data.enemy_spawn_timer = 0

    session_game_data.center_zone.progress = 0

    session_game_data.points_fade_text_timer = 0

    clear(&enemies)

    player.pos = { screen_width / 2, screen_height / 2 }
}


init_game :: proc() {
    // Screen size values
    screen_width: f32 = f32(raylib.GetScreenWidth())
    screen_height: f32 = f32(raylib.GetScreenHeight())

    // GameState
    game_state = .Main_Menu

    // Player default configs
    player = Player{
        pos = {screen_width / 2, screen_height / 2},
        speed = 600.0,
        radius = 20.0,
    }

    // Default Game Session configs
    session_game_data = SessionData{
        score = 0,
        deaths = 0,
        game_time = 0,
        enemy_spawn_timer = 0,
        center_zone = ConquestZone{
            pos = { screen_width / 2, screen_height / 2 },
            radius = 200.0,
            active = false,
        },
        high_score = load_highscore(),
        current_spawn_rate = 0.6,
        current_enemy_speed = 350.0,
        intro_fade_timer = INTRO_FADE_DURATION,
    }


    // Alocando na memória um espaço para o array dinamico de inimigos caso seja a primeira vez rodando o jogo
    if enemies == nil {
        enemies = make([dynamic]Enemy)
    } else {
        // Limpando os inimigos alocados caso ja exista (no caso de uma morte e reinicio de jogo por exemplo)
        clear(&enemies)
    }
}


update_game :: proc(dt: f32) {
    if session_game_data.intro_fade_timer > 0 {
        if session_game_data.intro_fade_timer > 3.0 {
            session_game_data.intro_fade_timer -= dt * 0.2
        } else {
            session_game_data.intro_fade_timer -= dt
        }
    }

    // GameStates Checks
    {
        // Check if is MainMenu
        if game_state == .Main_Menu {
            if raylib.IsKeyPressed(.ENTER) || raylib.IsKeyPressed(.SPACE) {
                game_state = .Playing
            }

            return
        }

        // Check if is GameOver
        if game_state == .Game_Over {
            if raylib.IsKeyPressed(.SPACE) {
                reset_session()
                game_state = .Playing
            }

            return
        }

        // Early return if gameState is not Playing
        if game_state != .Playing do return
    }
    
    screen_width: f32 = f32(raylib.GetScreenWidth())
    screen_height: f32 = f32(raylib.GetScreenHeight())

    session_game_data.game_time += dt
    session_game_data.enemy_spawn_timer += dt

    // Player movement
    {
        if raylib.IsKeyDown(.W) || raylib.IsKeyDown(.UP) do player.pos.y -= player.speed * dt
        if raylib.IsKeyDown(.S) || raylib.IsKeyDown(.DOWN) do player.pos.y += player.speed * dt
        if raylib.IsKeyDown(.A) || raylib.IsKeyDown(.LEFT) do player.pos.x -= player.speed * dt
        if raylib.IsKeyDown(.D) || raylib.IsKeyDown(.RIGHT) do player.pos.x += player.speed * dt
    }

    // Secury that player canot get out of the screen bounds
    {
        if player.pos.x < player.radius do player.pos.x = player.radius
        if player.pos.x > screen_width - player.radius do player.pos.x = screen_width - player.radius
        if player.pos.y < player.radius do player.pos.y = player.radius
        if player.pos.y > screen_height - player.radius do player.pos.y = screen_height - player.radius
    }

    // ConquestZone collider - Score calc
    {
        if raylib.CheckCollisionCircles(player.pos, player.radius, session_game_data.center_zone.pos, session_game_data.center_zone.radius) {
            session_game_data.center_zone.active = true
            session_game_data.center_zone.progress += dt * (1.0 / 3.0)

            if session_game_data.center_zone.progress >= 1.0 {
                session_game_data.score += 5
                session_game_data.center_zone.progress = 0

                session_game_data.points_fade_text_timer = 1.0
                session_game_data.points_fade_text_alpha = 1.0
            }
            
        } else {
            session_game_data.center_zone.active = false
            session_game_data.center_zone.progress -= dt * 0.5

            if session_game_data.center_zone.progress < 0 do session_game_data.center_zone.progress = 0
        }
    }

    // Progressive Dificulty 
    {
        session_game_data.current_spawn_rate = max(0.12, 0.6 - (session_game_data.score * 0.005))
        session_game_data.current_enemy_speed = min(850.0, 350.0 + (session_game_data.score * 2.5))
    }

    // Enemies
    {
        // Movement and Collision
        for &enemy in enemies {
            enemy.pos += enemy.vel * dt
    
            if raylib.CheckCollisionCircles(player.pos, player.radius, enemy.pos, enemy.radius) {
                session_game_data.deaths += 1
                
                if session_game_data.score > session_game_data.high_score {
                    session_game_data.high_score = session_game_data.score
                    save_highscore(session_game_data.high_score)
                }

                game_state = .Game_Over
            }
        } 

        // Spawn
        if session_game_data.enemy_spawn_timer > session_game_data.current_spawn_rate {
            new_enemy: Enemy
            new_enemy.radius = 10.0

            spawn_corner_side := raylib.GetRandomValue(0, 3)
            switch spawn_corner_side {
                case 0: //cima
                    new_enemy.pos = { f32(raylib.GetRandomValue(0, i32(screen_width))), -20 }
                case 1: //baixo
                    new_enemy.pos = { f32(raylib.GetRandomValue(0, i32(screen_width))), screen_height + 20 }
                case 2: //esquerda
                    new_enemy.pos = { -20, f32(raylib.GetRandomValue(0, i32(screen_height))) }
                case 3: //direita
                    new_enemy.pos = { screen_width + 20, f32(raylib.GetRandomValue(0, i32(screen_height))) }
            }

            enemy_direction := raylib.Vector2Normalize(session_game_data.center_zone.pos - new_enemy.pos)
            new_enemy.vel = enemy_direction * session_game_data.current_enemy_speed

            append(&enemies, new_enemy)
            session_game_data.enemy_spawn_timer = 0
        }

        // Clear enemies from screen and memory
        for i := 0; i < len(enemies); {
            if enemies[i].pos.x < -100 || enemies[i].pos.x > screen_width + 100 || enemies[i].pos.y < -100 || enemies[i].pos.y > screen_height + 100 {
                ordered_remove(&enemies, i)
            } else {
                i += 1
            }
        }
    }

    // Points fade out logic
    {
        if session_game_data.points_fade_text_timer > 0 {
            session_game_data.points_fade_text_timer -= dt
            session_game_data.points_fade_text_alpha = session_game_data.points_fade_text_timer / 1.0
        }
    }
}


draw_game :: proc() {
    raylib.BeginDrawing()
    raylib.ClearBackground(raylib.BLACK)

    screen_width: f32 = f32(raylib.GetScreenWidth())
    screen_height: f32 = f32(raylib.GetScreenHeight())

    // Draw MainMenu screen
    {
        if game_state == .Main_Menu {
            raylib.ClearBackground(raylib.DARKBLUE)

            // Game Title
            title_text := "MAGO MUSSARANHO"
            title_text_font_size: i32 = 130
            title_text_width := raylib.MeasureText(fmt.ctprintf(title_text), title_text_font_size)
            raylib.DrawText(fmt.ctprintf(title_text), i32(screen_width) / 2 - title_text_width / 2, i32(screen_height) / 2 - 160, title_text_font_size, raylib.WHITE)

            // Blinking subtitle instruction text
            subtitle_text := "Pressione Enter para começar"
            subtitle_text_font_size: i32 = 25
            if i32(raylib.GetTime() * 2) % 2 == 0 {
                subtitle_text_width := raylib.MeasureText(fmt.ctprintf(subtitle_text), subtitle_text_font_size)
                raylib.DrawText(fmt.ctprintf(subtitle_text), i32(screen_width) / 2 - subtitle_text_width / 2, i32(screen_height) / 2 + 20, subtitle_text_font_size, raylib.LIGHTGRAY)
            }

            exit_text: cstring = fmt.ctprintf("Pressione ESC para sair")
            exit_text_font_size: i32 = 15
            exit_text_width: i32 = raylib.MeasureText(exit_text, exit_text_font_size)
            raylib.DrawText(exit_text, i32(screen_width) / 2 - exit_text_width / 2, i32(screen_height) / 2 + 100, exit_text_font_size, raylib.LIGHTGRAY)

            // Fade in effect in the first 2 seconds 
            if session_game_data.intro_fade_timer > 0 {
                alpha: f32 = clamp(session_game_data.intro_fade_timer / 3.0, 0.0, 1.0)
                raylib.DrawRectangle(-1000, -1000, 5000, 5000, raylib.Fade(raylib.BLACK, alpha))
            }

            raylib.EndDrawing()
            return
        }
    }

    // Draw ConquestZone
    {
        zone: ConquestZone = session_game_data.center_zone
        zone_color := zone.active ? raylib.GREEN : raylib.DARKGRAY

        // Draw external circle line (the limit line)
        raylib.DrawCircleLinesV(zone.pos, zone.radius, zone_color)

        // Draw the circle color inside fill
        raylib.DrawCircleV(zone.pos, zone.radius * zone.progress, raylib.Fade(zone_color, 0.4))

        // Thin line showing better the progress
        raylib.DrawCircleLinesV(zone.pos, zone.radius * zone.progress, zone_color)
    }

    // Draw Player
    {
        raylib.DrawCircleV(player.pos, player.radius, raylib.WHITE)
    }
    
    // Draw Enemies
    {
        for enemy in enemies {
            raylib.DrawCircleV(enemy.pos, enemy.radius, raylib.RED)
        }
    }

    // Draw UI HUD
    {
        // Points fade text
        if session_game_data.points_fade_text_timer > 0 {
            points_fade_text_in_cstring := fmt.ctprintf("+5 PONTOS")
            points_fade_text_font_size: i32 = 80

            points_fade_text_width := raylib.MeasureText(points_fade_text_in_cstring, points_fade_text_font_size)
            
            points_fade_text_pos_x := i32(screen_width / 2) - (points_fade_text_width / 2)
            //floating effect in text (fly a bit)
            points_fade_text_pos_y := i32(200 - (1.0 - session_game_data.points_fade_text_alpha) * 80)

            raylib.DrawText(
                points_fade_text_in_cstring, 
                points_fade_text_pos_x, 
                points_fade_text_pos_y, 
                points_fade_text_font_size, 
                raylib.Fade(raylib.GREEN, session_game_data.points_fade_text_alpha)
            )
        }


        // In game infos (in top of the screen)
        score_text_formatted := fmt.ctprintf("PONTOS: %.0f", session_game_data.score) 
        raylib.DrawText(score_text_formatted, 30, 30, 50, raylib.GOLD)

        raylib.DrawText(fmt.ctprintf("Tempo: %.1fs", session_game_data.game_time), 30, 90, 40, raylib.RAYWHITE)
        raylib.DrawText(fmt.ctprintf("Mortes: %d", session_game_data.deaths), 30, 140, 40, raylib.RED)
        
        raylib.DrawFPS(raylib.GetScreenWidth() - 120, 30)
    }

    // Draw Game Over screen
    {
        if game_state == .Game_Over {
            // Turn Background darker
            raylib.DrawRectangle(0, 0, i32(screen_width), i32(screen_height), raylib.Fade(raylib.BLACK, 0.8))

            death_msg: string = "VOCE MORREU!"
            death_msg_font_size: i32 = 60 
            death_msg_width: i32 = raylib.MeasureText(fmt.ctprintf(death_msg), death_msg_font_size)
            raylib.DrawText(fmt.ctprintf(death_msg), i32(screen_width) / 2 - death_msg_width / 2, i32(screen_height) / 2 - 100, death_msg_font_size, raylib.RED)
            
            score_msg: cstring = fmt.ctprintf("Score: %.0f", session_game_data.score)
            score_msg_font_size: i32 = 30
            score_msg_width: i32 = raylib.MeasureText(score_msg, score_msg_font_size)
            raylib.DrawText(score_msg, i32(screen_width) / 2 - score_msg_width / 2, i32(screen_height) / 2, score_msg_font_size, raylib.WHITE)

            highscore_msg: cstring = fmt.ctprintf("Recorde: %.0f", session_game_data.high_score)
            highscore_msg_font_size: i32 = 30
            highscore_msg_width: i32 = raylib.MeasureText(highscore_msg, highscore_msg_font_size)
            raylib.DrawText(highscore_msg, i32(screen_width) / 2 - highscore_msg_width / 2, i32(screen_height) / 2 + 40, highscore_msg_font_size, raylib.GOLD)

            instruction_msg: cstring = fmt.ctprintf("pressione ESPAÇO para tentar de novo")
            instruction_msg_font_size: i32 = 20
            instruction_msg_width: i32 = raylib.MeasureText(instruction_msg, instruction_msg_font_size)
            raylib.DrawText(instruction_msg, i32(screen_width) / 2 - instruction_msg_width / 2, i32(screen_height) / 2 + 120, instruction_msg_font_size, raylib.GRAY)
        }
    }

    raylib.EndDrawing()
}


save_highscore :: proc(score: f32) {
    score_str := fmt.tprintf("%f", score)

    errnone := os.write_entire_file("save.dat", transmute([]u8)score_str)

    // In ODIN, ERROR NONE is 0, that means success. Anything different than that is a error
    if errnone != os.ERROR_NONE {
        fmt.println("ERRO: Não foi possivel salvar o recorde! Código: ", errnone)
    } else {
        fmt.println("Sucesso: Recorde salvo com sucesso.")
    }
}


load_highscore :: proc() -> f32 {
    if !os.exists("save.dat") do return 0

    data, err := os.read_entire_file_from_path("save.dat", context.allocator)

    if err != os.ERROR_NONE {
        fmt.println("Erro ao ler save.dat: ", err)
        return 0
    }

    defer delete(data, context.allocator)

    val, _ := strconv.parse_f32(string(data))
    
    return val
}


deinit_game :: proc() {
    // liberar memória aqui
    delete(enemies)
}