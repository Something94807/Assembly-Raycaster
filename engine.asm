section .data
    title         db "Raycaster", 0
    map           db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
                  db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

    two             dq 2.0
    one             dq 1.0
    zero            dq 0.0
    half            dq 0.5
    init_posX       dq 8.5
    init_posY       dq 8.5
    init_planeY     dq 0.66
    neg_one         dq -1.0
    rot_speed       dq 0.04
    neg_rot_speed   dq -0.04
    move_speed      dq 0.05
    align 16
    abs_mask        dq 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
    sign_mask       dq 0x8000000000000000, 0x8000000000000000
    screen_height   dq 480.0
    half_height     dq 240.0
    screen_width    dq 640.0
    max_height      dq 479.0
    width_minus_one dq 639.0
    ; flashlight constants
    flash_intensity dq 6.0      ; overall brightness multiplier - raise to brighten
    flash_falloff   dq 3.0      ; angular falloff power - raise for tighter beam
    flash_min       dq 0.0
    flash_max       dq 255.0
    fog_cutoff      dq 7.0      ; PS1-style hard fog: columns beyond this distance are black
    ; minimap constants - top-left corner at (8, 8), each cell = 10px
    mm_orig_x       dd 8
    mm_orig_y       dd 8
    mm_cell         dd 10
    mm_size         dd 16
    ; player dot is 3x3 centered on player pos
    mm_dot          dd 3

section .bss
    event           resb 56
    window_ptr      resq 1
    renderer_ptr    resq 1
    keys_ptr        resq 1
    save_angle      resq 1
    save_cos        resq 1
    save_sin        resq 1
    posX            resq 1
    posY            resq 1
    planeX          resq 1
    planeY          resq 1
    dirX            resq 1
    dirY            resq 1
    save_rayDirX    resq 1
    save_rayDirY    resq 1
    save_deltaDistX resq 1
    save_deltaDistY resq 1
    save_sideDistX  resq 1
    save_sideDistY  resq 1
    save_mapX       resq 1
    save_mapY       resq 1
    save_stepX      resq 1
    save_stepY      resq 1
    save_side       resq 1
    save_col        resq 1
    save_drawStart  resq 1
    save_drawEnd    resq 1
    save_lineHeight resq 1
    save_perpDist   resq 1      ; NEW: save perpWallDist for flashlight calc
    save_cameraX    resq 1      ; NEW: save cameraX for flashlight calc
    floor_rect      resb 16
    ; scratch rect for minimap cells
    mm_rect         resb 16

section .text
    global main
    extern SDL_Init, SDL_CreateWindow, SDL_CreateRenderer
    extern SDL_PollEvent, SDL_Quit, SDL_GetKeyboardState
    extern SDL_RenderClear, SDL_SetRenderDrawColor
    extern SDL_RenderPresent, SDL_RenderDrawLine
    extern SDL_RenderFillRect
    extern cos, sin

main:
    sub rsp, 8

    movsd xmm0, [init_posX]
    movsd [posX], xmm0
    movsd xmm0, [init_posY]
    movsd [posY], xmm0
    mov qword [planeX], 0
    movsd xmm0, [init_planeY]
    movsd [planeY], xmm0
    movsd xmm0, [neg_one]
    movsd [dirX], xmm0
    mov qword [dirY], 0

    ; floor rect: x=0 y=240 w=640 h=240
    mov dword [floor_rect],      0
    mov dword [floor_rect + 4],  240
    mov dword [floor_rect + 8],  640
    mov dword [floor_rect + 12], 240

    mov edi, 0x20
    call SDL_Init

    mov rdi, title
    mov esi, 0x2FFF0000
    mov edx, 0x2FFF0000
    mov ecx, 640
    mov r8d,  480
    mov r9d,  0
    call SDL_CreateWindow

    mov [window_ptr], rax
    test rax, rax
    jz .quit

    mov rdi, [window_ptr]
    mov rsi, -1
    mov rdx, 6
    call SDL_CreateRenderer
    mov [renderer_ptr], rax

.loop:
    mov rdi, event
    call SDL_PollEvent
    test eax, eax
    jz .render

    mov eax, dword [event]
    cmp eax, 0x100
    jne .loop

.quit:
    call SDL_Quit
    xor eax, eax
    add rsp, 8
    ret

.render:
    ; clear to black
    mov rdi, [renderer_ptr]
    xor rsi, rsi
    xor rdx, rdx
    xor rcx, rcx
    mov r8, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renderer_ptr]
    call SDL_RenderClear

    ; draw floor (dark blue rectangle, bottom half)
    mov rdi, [renderer_ptr]
    mov rsi, 0
    mov rdx, 0
    mov rcx, 40
    mov r8, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renderer_ptr]
    mov rsi, floor_rect
    call SDL_RenderFillRect

    xor edi, edi
    call SDL_GetKeyboardState
    mov [keys_ptr], rax

    mov rax, [keys_ptr]
    cmp byte [rax + 79], 1
    je .rotate_right
    cmp byte [rax + 7], 1
    je .rotate_right
    cmp byte [rax + 80], 1
    je .rotate_left
    cmp byte [rax + 4], 1
    je .rotate_left
    jmp .check_move

.rotate_right:
    movsd xmm0, [neg_rot_speed]
    jmp .do_rotate

.rotate_left:
    movsd xmm0, [rot_speed]

.do_rotate:
    movsd [save_angle], xmm0

    call cos
    movsd [save_cos], xmm0

    movsd xmm0, [save_angle]
    call sin
    movsd [save_sin], xmm0

    movsd xmm0, [dirX]
    movsd xmm1, [dirY]
    movsd xmm2, [save_cos]
    movsd xmm3, [save_sin]
    movsd xmm4, xmm0
    mulsd xmm0, xmm2
    mulsd xmm1, xmm3
    subsd xmm0, xmm1
    movsd [dirX], xmm0

    movsd xmm0, xmm4
    movsd xmm1, [dirY]
    mulsd xmm0, xmm3
    mulsd xmm1, xmm2
    addsd xmm0, xmm1
    movsd [dirY], xmm0

    movsd xmm0, [planeX]
    movsd xmm1, [planeY]
    movsd xmm4, xmm0
    mulsd xmm0, xmm2
    mulsd xmm1, xmm3
    subsd xmm0, xmm1
    movsd [planeX], xmm0

    movsd xmm0, xmm4
    movsd xmm1, [planeY]
    mulsd xmm0, xmm3
    mulsd xmm1, xmm2
    addsd xmm0, xmm1
    movsd [planeY], xmm0

.check_move:
    mov rax, [keys_ptr]
    cmp byte [rax + 82], 1
    je .move_forward
    cmp byte [rax + 26], 1
    je .move_forward
    cmp byte [rax + 81], 1
    je .move_backward
    cmp byte [rax + 22], 1
    je .move_backward
    jmp .do_raycast

.move_forward:
    movsd xmm0, [posX]
    movsd xmm1, [dirX]
    mulsd xmm1, [move_speed]
    addsd xmm0, xmm1
    movsd [posX], xmm0

    movsd xmm0, [posY]
    movsd xmm1, [dirY]
    mulsd xmm1, [move_speed]
    addsd xmm0, xmm1
    movsd [posY], xmm0
    jmp .do_raycast

.move_backward:
    movsd xmm0, [posX]
    movsd xmm1, [dirX]
    mulsd xmm1, [move_speed]
    subsd xmm0, xmm1
    movsd [posX], xmm0

    movsd xmm0, [posY]
    movsd xmm1, [dirY]
    mulsd xmm1, [move_speed]
    subsd xmm0, xmm1
    movsd [posY], xmm0

.do_raycast:
    call raycast
    call draw_minimap

    mov rdi, [renderer_ptr]
    call SDL_RenderPresent
    jmp main.loop

; ─────────────────────────────────────────────────────────────────────────────
; raycast: cast one ray per column, compute flashlight brightness, draw wall
; ─────────────────────────────────────────────────────────────────────────────
raycast:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 8

    mov ecx, 0

.loop:
    cmp ecx, 640
    jge .loop_end

    ; cameraX in [-1, 1]
    cvtsi2sd xmm0, ecx
    mulsd xmm0, [two]
    divsd xmm0, [screen_width]
    subsd xmm0, [one]
    movsd [save_cameraX], xmm0   ; save for flashlight

    ; ray direction
    movsd xmm2, [dirX]
    movsd xmm3, [planeX]
    mulsd xmm3, xmm0
    addsd xmm2, xmm3              ; xmm2 = rayDirX

    movsd xmm4, [dirY]
    movsd xmm5, [planeY]
    mulsd xmm5, xmm0
    addsd xmm4, xmm5              ; xmm4 = rayDirY

    ; deltaDist
    movsd xmm0, [one]
    divsd xmm0, xmm2
    andpd xmm0, [abs_mask]        ; xmm0 = deltaDistX

    movsd xmm3, [one]
    divsd xmm3, xmm4
    andpd xmm3, [abs_mask]        ; xmm3 = deltaDistY

    ; map cell via floor
    movsd xmm1, [posX]
    roundsd xmm8, xmm1, 1
    cvtsd2si r12, xmm8

    movsd xmm1, [posY]
    roundsd xmm8, xmm1, 1
    cvtsd2si r13, xmm8

    xorpd xmm9, xmm9

    ; sideDistX init
    ucomisd xmm2, xmm9
    jb .rayX_negative

    mov r14, 1
    movsd xmm1, [posX]
    roundsd xmm8, xmm1, 1
    addsd xmm8, [one]
    subsd xmm8, xmm1
    movsd xmm6, xmm2
    andpd xmm6, [abs_mask]
    divsd xmm8, xmm6
    movsd xmm6, xmm8
    jmp .rayX_done

.rayX_negative:
    mov r14, -1
    movsd xmm1, [posX]
    roundsd xmm8, xmm1, 1
    subsd xmm1, xmm8
    movsd xmm6, xmm2
    andpd xmm6, [abs_mask]
    divsd xmm1, xmm6
    movsd xmm6, xmm1

.rayX_done:
    ; sideDistY init
    ucomisd xmm4, xmm9
    jb .rayY_negative

    mov r15, 1
    movsd xmm1, [posY]
    roundsd xmm8, xmm1, 1
    addsd xmm8, [one]
    subsd xmm8, xmm1
    movsd xmm7, xmm4
    andpd xmm7, [abs_mask]
    divsd xmm8, xmm7
    movsd xmm7, xmm8
    jmp .dda

.rayY_negative:
    mov r15, -1
    movsd xmm1, [posY]
    roundsd xmm8, xmm1, 1
    subsd xmm1, xmm8
    movsd xmm7, xmm4
    andpd xmm7, [abs_mask]
    divsd xmm1, xmm7
    movsd xmm7, xmm1

.dda:
    mov rbx, 0
    mov rbp, 0

    movsd [save_rayDirX], xmm2
    movsd [save_rayDirY], xmm4

.dda_loop:
    test rbx, rbx
    jnz .dda_done

    ucomisd xmm6, xmm7
    ja .sideY_step

    addsd xmm6, xmm0
    add r12, r14
    mov rbp, 0
    jmp .wall_check

.sideY_step:
    addsd xmm7, xmm3
    add r13, r15
    mov rbp, 1

.wall_check:
    cmp r12, 0
    jl .dda_loop
    cmp r12, 15
    jg .dda_loop
    cmp r13, 0
    jl .dda_loop
    cmp r13, 15
    jg .dda_loop
    mov rax, r13
    shl rax, 4
    add rax, r12
    movzx rax, byte [map + rax]
    test rax, rax
    jz .dda_loop
    mov rbx, 1

.dda_done:
    ; perpWallDist
    test rbp, rbp
    jz .x_wall

    cvtsi2sd xmm10, r13
    movsd xmm11, [posY]
    subsd xmm10, xmm11
    movsd xmm11, [one]
    cvtsi2sd xmm12, r15
    subsd xmm11, xmm12
    divsd xmm11, [two]
    addsd xmm10, xmm11
    movsd xmm11, [save_rayDirY]
    divsd xmm10, xmm11
    andpd xmm10, [abs_mask]
    jmp .height_calc

.x_wall:
    cvtsi2sd xmm10, r12
    movsd xmm11, [posX]
    subsd xmm10, xmm11
    movsd xmm11, [one]
    cvtsi2sd xmm12, r14
    subsd xmm11, xmm12
    divsd xmm11, [two]
    addsd xmm10, xmm11
    movsd xmm11, [save_rayDirX]
    divsd xmm10, xmm11
    andpd xmm10, [abs_mask]

.height_calc:
    movsd [save_perpDist], xmm10  ; save perpWallDist for flashlight

    movsd xmm1, [screen_height]
    divsd xmm1, xmm10
    cvtsd2si r11, xmm1

    cvtsi2sd xmm11, r11
    xorpd xmm11, [sign_mask]
    divsd xmm11, [two]
    addsd xmm11, [half_height]
    maxsd xmm11, [zero]
    cvtsd2si rax, xmm11

    cvtsi2sd xmm12, r11
    divsd xmm12, [two]
    addsd xmm12, [half_height]
    minsd xmm12, [max_height]
    cvtsd2si rdx, xmm12

    mov [save_col],        rcx
    mov [save_mapX],       r12
    mov [save_mapY],       r13
    mov [save_stepX],      r14
    mov [save_stepY],      r15
    mov [save_side],       rbp
    mov [save_drawStart],  rax
    mov [save_drawEnd],    rdx
    mov [save_lineHeight], r11
    movsd [save_deltaDistX], xmm0
    movsd [save_deltaDistY], xmm3
    movsd [save_sideDistX],  xmm6
    movsd [save_sideDistY],  xmm7

    ; ── PS1-style fog cutoff ─────────────────────────────────────────────────
    ; if perpWallDist >= fog_cutoff, draw black and skip brightness calc
    movsd xmm9, [save_perpDist]
    ucomisd xmm9, [fog_cutoff]
    jae .draw_black

    ; ── flashlight brightness calculation ────────────────────────────────────
    ;
    ; angular_factor = 1.0 - cameraX^2        (1.0 at center, 0.0 at edges)
    ; dist_factor    = flash_intensity / perpWallDist
    ; brightness     = clamp(angular_factor * dist_factor * 255, 0, 255)
    ;
    ; Y-side walls get an extra 0.5x dim on top of this.
    ; ─────────────────────────────────────────────────────────────────────────

    movsd xmm0, [save_cameraX]
    mulsd xmm0, xmm0              ; cameraX^2
    movsd xmm1, [one]
    subsd xmm1, xmm0              ; angular = 1 - cameraX^2
    maxsd xmm1, [zero]

    movsd xmm0, [flash_intensity]
    movsd xmm2, [save_perpDist]
    divsd xmm0, xmm2              ; dist_factor = intensity / perpDist

    mulsd xmm1, xmm0              ; angular * dist_factor

    movsd xmm0, [flash_max]       ; 255.0
    mulsd xmm1, xmm0              ; scale to 0-255

    ; dim Y-side walls by half
    mov rax, [save_side]
    test rax, rax
    jz .no_dim
    mulsd xmm1, [half]

.no_dim:
    maxsd xmm1, [flash_min]
    minsd xmm1, [flash_max]
    cvtsd2si rsi, xmm1            ; rsi = raw brightness 0-255

    ; ── PS1-style brightness banding (4 steps) ───────────────────────────────
    cmp rsi, 48
    jl  .band0
    cmp rsi, 112
    jl  .band1
    cmp rsi, 180
    jl  .band2
    mov rsi, 220
    jmp .band_done
.band0: xor rsi, rsi
    jmp .band_done
.band1: mov rsi, 64
    jmp .band_done
.band2: mov rsi, 140
.band_done:

    ; ── PS1-style muddy green-grey tint ──────────────────────────────────────
    ; R = rsi, G = rsi * 0.75 (greenish), B = rsi * 0.45 (desaturated)
    ; compute G = rsi * 3 / 4
    mov rax, rsi
    imul rax, 3
    shr rax, 2                    ; rax = G channel
    ; compute B = rsi * 115 / 256  (~0.45)
    mov rbx, rsi
    imul rbx, 115
    shr rbx, 8                    ; rbx = B channel

    mov rdi, [renderer_ptr]
    mov rdx, rax                  ; G
    mov rcx, rbx                  ; B
    mov r8,  255
    call SDL_SetRenderDrawColor
    jmp .do_draw

.draw_black:
    ; fog: solid black column
    xor rsi, rsi
    mov rdi, [renderer_ptr]
    xor rdx, rdx
    xor rcx, rcx
    mov r8,  255
    call SDL_SetRenderDrawColor

.do_draw:
    ; ── draw 2px-wide column (half-res) ──────────────────────────────────────
    mov rdi, [renderer_ptr]
    mov rsi, [save_col]
    mov rdx, [save_drawStart]
    mov rcx, [save_col]
    mov r8,  [save_drawEnd]
    call SDL_RenderDrawLine

    ; second pixel (col+1) for 2px width
    mov rdi, [renderer_ptr]
    mov rsi, [save_col]
    inc rsi
    mov rdx, [save_drawStart]
    mov rcx, [save_col]
    inc rcx
    mov r8,  [save_drawEnd]
    call SDL_RenderDrawLine

    ; restore registers clobbered by SDL calls
    mov rcx, [save_col]
    mov r12, [save_mapX]
    mov r13, [save_mapY]
    mov r14, [save_stepX]
    mov r15, [save_stepY]
    mov rbp, [save_side]
    movsd xmm0, [save_deltaDistX]
    movsd xmm3, [save_deltaDistY]
    movsd xmm6, [save_sideDistX]
    movsd xmm7, [save_sideDistY]

    add ecx, 2          ; half-res: step 2 columns at a time
    jmp .loop

.loop_end:
    add rsp, 8
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; draw_minimap
;
; Draws a 16x16 tile map in the top-left corner.
; Each tile is mm_cell (10) pixels square.
; Walls: white. Floor: dark grey. Player: yellow dot.
; ─────────────────────────────────────────────────────────────────────────────
draw_minimap:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp
    sub rsp, 8

    ; draw semi-transparent background for minimap area
    mov rdi, [renderer_ptr]
    mov rsi, 20
    mov rdx, 20
    mov rcx, 20
    mov r8, 255
    call SDL_SetRenderDrawColor

    ; background rect covers entire minimap: 8 + 16*10 = 168px square
    mov dword [mm_rect],      6
    mov dword [mm_rect + 4],  6
    mov dword [mm_rect + 8],  164
    mov dword [mm_rect + 12], 164
    mov rdi, [renderer_ptr]
    mov rsi, mm_rect
    call SDL_RenderFillRect

    ; iterate all 16x16 map cells
    xor r13, r13          ; row (mapY)

.mm_row_loop:
    cmp r13, 16
    jge .mm_done_tiles

    xor r12, r12          ; col (mapX)

.mm_col_loop:
    cmp r12, 16
    jge .mm_next_row

    ; read map cell
    mov rax, r13
    shl rax, 4
    add rax, r12
    movzx rax, byte [map + rax]

    ; compute pixel rect for this cell
    ; x = mm_orig_x + col * mm_cell
    ; y = mm_orig_y + row * mm_cell
    mov rbx, r12
    imul rbx, [mm_cell]
    add rbx, [mm_orig_x]    ; rbx = pixel x

    mov r14, r13
    imul r14, [mm_cell]
    add r14, [mm_orig_y]    ; r14 = pixel y

    mov dword [mm_rect],      ebx
    mov dword [mm_rect + 4],  r14d
    mov dword [mm_rect + 8],  10    ; width  = mm_cell
    mov dword [mm_rect + 12], 10    ; height = mm_cell

    test rax, rax
    jz .mm_floor_cell

.mm_wall_cell:
    ; wall = white
    mov rdi, [renderer_ptr]
    mov rsi, 200
    mov rdx, 200
    mov rcx, 200
    mov r8, 255
    call SDL_SetRenderDrawColor
    jmp .mm_fill_cell

.mm_floor_cell:
    ; floor = dark grey
    mov rdi, [renderer_ptr]
    mov rsi, 50
    mov rdx, 50
    mov rcx, 50
    mov r8, 255
    call SDL_SetRenderDrawColor

.mm_fill_cell:
    mov rdi, [renderer_ptr]
    mov rsi, mm_rect
    call SDL_RenderFillRect

    inc r12
    jmp .mm_col_loop

.mm_next_row:
    inc r13
    jmp .mm_row_loop

.mm_done_tiles:
    ; draw player dot: yellow, 3x3 pixels centered on player world position
    ; dot_x = mm_orig_x + posX * mm_cell - 1
    ; dot_y = mm_orig_y + posY * mm_cell - 1
    movsd xmm0, [posX]
    movsd xmm1, [posY]

    cvtsi2sd xmm2, dword [mm_cell]
    mulsd xmm0, xmm2              ; posX * cell_size
    mulsd xmm1, xmm2              ; posY * cell_size

    cvtsd2si rax, xmm0
    add rax, [mm_orig_x]
    sub rax, 1                    ; center the 3px dot
    mov dword [mm_rect], eax

    cvtsd2si rax, xmm1
    add rax, [mm_orig_y]
    sub rax, 1
    mov dword [mm_rect + 4], eax

    mov dword [mm_rect + 8],  3
    mov dword [mm_rect + 12], 3

    ; yellow player dot
    mov rdi, [renderer_ptr]
    mov rsi, 255
    mov rdx, 255
    mov rcx, 0
    mov r8, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renderer_ptr]
    mov rsi, mm_rect
    call SDL_RenderFillRect

    ; draw player direction indicator: a short line from player center
    ; toward dirX/dirY, scaled by mm_cell/2 pixels
    ; line end = player_dot_center + dir * (mm_cell/2)
    movsd xmm0, [posX]
    movsd xmm1, [posY]
    cvtsi2sd xmm2, dword [mm_cell]
    mulsd xmm0, xmm2
    mulsd xmm1, xmm2

    cvtsi2sd xmm3, dword [mm_orig_x]
    cvtsi2sd xmm4, dword [mm_orig_y]
    addsd xmm0, xmm3              ; pixel center X
    addsd xmm1, xmm4              ; pixel center Y

    movsd xmm3, [dirX]
    movsd xmm4, [dirY]
    movsd xmm5, xmm2
    mulsd xmm5, [half]            ; scale = mm_cell * 0.5
    mulsd xmm3, xmm5
    mulsd xmm4, xmm5

    addsd xmm3, xmm0              ; end X
    addsd xmm4, xmm1              ; end Y

    cvtsd2si rsi, xmm0            ; start X (int)
    cvtsd2si rdx, xmm1            ; start Y (int)
    cvtsd2si rcx, xmm3            ; end X (int)
    cvtsd2si r8,  xmm4            ; end Y (int)

    ; cyan direction line
    mov rdi, [renderer_ptr]
    push rsi
    push rdx
    push rcx
    push r8
    mov rsi, 0
    mov rdx, 255
    mov rcx, 255
    mov r8,  255
    call SDL_SetRenderDrawColor
    pop r8
    pop rcx
    pop rdx
    pop rsi

    mov rdi, [renderer_ptr]
    call SDL_RenderDrawLine

    add rsp, 8
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits