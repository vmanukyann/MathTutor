import pygame
import sys

# Initialize Pygame
pygame.init()

# Set up display
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Box in Center")

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# Box properties
box_width = 100
box_height = 100
box_x = (WIDTH - box_width) // 2
box_y = (HEIGHT - box_height) // 2

# Game loop
running = True
clock = pygame.time.Clock()

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    
    # Fill background white
    screen.fill(WHITE)
    
    # Draw black box in center
    pygame.draw.rect(screen, BLACK, (box_x, box_y, box_width, box_height))
    
    # Update display
    pygame.display.flip()
    clock.tick(60)

pygame.quit()