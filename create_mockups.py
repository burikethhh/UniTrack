"""
UniTrack UI Mockup Generator
Creates wireframe mockups for the UniTrack app
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
DARK_BLUE = (0, 51, 102)
LIGHT_BLUE = (230, 242, 255)
GREEN = (0, 153, 76)
LIGHT_GREEN = (220, 255, 220)
GRAY = (128, 128, 128)
LIGHT_GRAY = (240, 240, 240)
RED = (220, 53, 69)
ORANGE = (255, 165, 0)

def draw_phone_frame(draw, width, height):
    """Draw phone frame"""
    # Phone body
    draw.rounded_rectangle([20, 10, width-20, height-10], radius=30, fill=WHITE, outline=DARK_BLUE, width=3)
    # Status bar
    draw.rectangle([20, 10, width-20, 60], fill=DARK_BLUE)
    # Status bar text
    draw.text((40, 25), "9:41", fill=WHITE)
    draw.text((width-80, 25), "100%", fill=WHITE)
    # Home indicator
    draw.rounded_rectangle([width//2-50, height-40, width//2+50, height-30], radius=5, fill=GRAY)

def draw_bottom_nav(draw, width, height, active=0):
    """Draw bottom navigation bar"""
    nav_y = height - 100
    draw.rectangle([20, nav_y, width-20, height-50], fill=WHITE, outline=LIGHT_GRAY)
    
    # Nav items
    items = ["🏠", "🗺️", "👤", "⚙️"]
    labels = ["Home", "Map", "Profile", "Settings"]
    item_width = (width - 40) // 4
    
    for i, (icon, label) in enumerate(zip(items, labels)):
        x = 20 + i * item_width + item_width // 2
        color = GREEN if i == active else GRAY
        draw.text((x-10, nav_y + 15), icon, fill=color)
        draw.text((x-20, nav_y + 45), label, fill=color)

def create_staff_dashboard():
    """Create Staff Module Dashboard mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Header
    draw.rectangle([20, 60, width-20, 130], fill=DARK_BLUE)
    draw.text((40, 80), "UniTrack - Staff", fill=WHITE)
    draw.text((width-100, 85), "Online", fill=GREEN)
    
    # Profile section
    draw.rounded_rectangle([40, 150, width-40, 280], radius=15, fill=WHITE)
    draw.ellipse([60, 170, 130, 240], fill=LIGHT_BLUE, outline=DARK_BLUE, width=2)
    draw.text((80, 195), "CK", fill=DARK_BLUE)
    draw.text((150, 180), "Christian Keth", fill=BLACK)
    draw.text((150, 205), "Faculty Member", fill=GRAY)
    draw.text((150, 230), "📍 Admin Building", fill=GREEN)
    
    # Privacy Toggle (BIG)
    draw.rounded_rectangle([40, 300, width-40, 400], radius=15, fill=WHITE)
    draw.text((60, 320), "Location Sharing", fill=BLACK)
    # Toggle switch ON
    draw.rounded_rectangle([width-120, 315, width-60, 355], radius=20, fill=GREEN)
    draw.ellipse([width-90, 320, width-65, 350], fill=WHITE)
    draw.text((60, 360), "You are visible to students", fill=GREEN)
    
    # Status section
    draw.rounded_rectangle([40, 420, width-40, 580], radius=15, fill=WHITE)
    draw.text((60, 440), "Current Status", fill=BLACK)
    
    # Status buttons
    statuses = [("Available", GREEN), ("In Class", ORANGE), ("Meeting", RED)]
    for i, (status, color) in enumerate(statuses):
        y = 480 + i * 35
        if i == 0:
            draw.rounded_rectangle([60, y-5, width-60, y+25], radius=10, fill=color)
            draw.text((80, y), status, fill=WHITE)
        else:
            draw.rounded_rectangle([60, y-5, width-60, y+25], radius=10, outline=color, width=2)
            draw.text((80, y), status, fill=color)
    
    # Quick message
    draw.rounded_rectangle([40, 600, width-40, 680], radius=15, fill=WHITE)
    draw.text((60, 620), "Quick Message", fill=BLACK)
    draw.rounded_rectangle([60, 645, width-60, 670], radius=8, fill=LIGHT_GRAY)
    draw.text((70, 650), "Back in 10 minutes...", fill=GRAY)
    
    draw_bottom_nav(draw, width, height, active=0)
    
    return img

def create_student_directory():
    """Create Student Directory mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Header
    draw.rectangle([20, 60, width-20, 130], fill=GREEN)
    draw.text((40, 80), "UniTrack - Find Faculty", fill=WHITE)
    
    # Search bar
    draw.rounded_rectangle([40, 145, width-40, 185], radius=10, fill=WHITE)
    draw.text((60, 155), "🔍 Search faculty...", fill=GRAY)
    
    # Filter tabs
    tabs = ["All", "Available", "Department"]
    tab_width = (width - 80) // 3
    for i, tab in enumerate(tabs):
        x = 40 + i * tab_width
        if i == 1:
            draw.rounded_rectangle([x, 195, x+tab_width-5, 225], radius=8, fill=GREEN)
            draw.text((x+15, 202), tab, fill=WHITE)
        else:
            draw.rounded_rectangle([x, 195, x+tab_width-5, 225], radius=8, outline=GREEN, width=2)
            draw.text((x+15, 202), tab, fill=GREEN)
    
    # Faculty list
    faculty = [
        ("Dr. Santos", "IT Department", "Available", GREEN),
        ("Prof. Garcia", "CS Department", "In Class", ORANGE),
        ("Dr. Reyes", "IT Department", "Available", GREEN),
        ("Prof. Cruz", "Math Dept", "Meeting", RED),
    ]
    
    y_start = 245
    for i, (name, dept, status, color) in enumerate(faculty):
        y = y_start + i * 90
        draw.rounded_rectangle([40, y, width-40, y+80], radius=12, fill=WHITE)
        # Avatar
        draw.ellipse([55, y+15, 100, y+60], fill=LIGHT_BLUE, outline=DARK_BLUE, width=2)
        # Info
        draw.text((115, y+15), name, fill=BLACK)
        draw.text((115, y+40), dept, fill=GRAY)
        # Status badge
        draw.rounded_rectangle([width-130, y+25, width-55, y+50], radius=10, fill=color)
        draw.text((width-125, y+30), status[:6], fill=WHITE)
        # Navigate button
        draw.text((width-50, y+30), "→", fill=DARK_BLUE)
    
    draw_bottom_nav(draw, width, height, active=0)
    
    return img

def create_live_map():
    """Create Live Map View mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Map area (simulate map with grid)
    draw.rectangle([20, 60, width-20, height-110], fill=(220, 235, 220))
    
    # Draw road grid
    for i in range(5):
        y = 100 + i * 120
        draw.line([(30, y), (width-30, y)], fill=WHITE, width=8)
    for i in range(4):
        x = 60 + i * 90
        draw.line([(x, 70), (x, height-120)], fill=WHITE, width=8)
    
    # Buildings
    buildings = [
        (50, 120, 140, 200, "Admin\nBuilding"),
        (160, 120, 250, 200, "IT\nBuilding"),
        (260, 120, 350, 200, "Library"),
        (50, 320, 140, 400, "Canteen"),
        (160, 320, 250, 400, "Gym"),
        (260, 320, 350, 400, "Science\nBuilding"),
    ]
    
    for x1, y1, x2, y2, name in buildings:
        draw.rectangle([x1, y1, x2, y2], fill=LIGHT_BLUE, outline=DARK_BLUE, width=2)
        draw.text((x1+10, y1+30), name, fill=DARK_BLUE)
    
    # Faculty markers
    markers = [
        (90, 160, "Dr. S", GREEN),
        (200, 350, "Prof. G", ORANGE),
        (300, 160, "Dr. R", GREEN),
    ]
    
    for x, y, name, color in markers:
        # Pin shape
        draw.ellipse([x-15, y-15, x+15, y+15], fill=color, outline=WHITE, width=3)
        draw.polygon([(x-10, y+10), (x+10, y+10), (x, y+30)], fill=color)
        draw.text((x-12, y-8), name[:4], fill=WHITE)
    
    # Current location (blue dot)
    draw.ellipse([185, 530, 215, 560], fill=DARK_BLUE, outline=WHITE, width=3)
    draw.text((175, 565), "You", fill=DARK_BLUE)
    
    # Top bar overlay
    draw.rounded_rectangle([40, 80, width-40, 120], radius=10, fill=WHITE)
    draw.text((60, 90), "🔍 Dr. Santos", fill=BLACK)
    draw.text((width-80, 90), "2 min", fill=GREEN)
    
    # Bottom info card
    draw.rounded_rectangle([40, height-180, width-40, height-115], radius=15, fill=WHITE)
    draw.text((60, height-170), "Dr. Santos", fill=BLACK)
    draw.text((60, height-145), "📍 Admin Building • Available", fill=GREEN)
    
    # Navigate button
    draw.rounded_rectangle([width-140, height-165, width-55, height-130], radius=10, fill=GREEN)
    draw.text((width-130, height-155), "Navigate", fill=WHITE)
    
    draw_bottom_nav(draw, width, height, active=1)
    
    return img

def create_navigation_screen():
    """Create Navigation Screen mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Map with route
    draw.rectangle([20, 60, width-20, height-110], fill=(220, 235, 220))
    
    # Draw simplified map
    for i in range(5):
        y = 100 + i * 120
        draw.line([(30, y), (width-30, y)], fill=WHITE, width=8)
    for i in range(4):
        x = 60 + i * 90
        draw.line([(x, 70), (x, height-120)], fill=WHITE, width=8)
    
    # Buildings
    draw.rectangle([50, 120, 140, 200], fill=LIGHT_BLUE, outline=DARK_BLUE, width=2)
    draw.text((55, 150), "Admin", fill=DARK_BLUE)
    
    # Route line (dotted path)
    route_points = [(200, 545), (200, 400), (200, 250), (150, 250), (100, 200)]
    for i in range(len(route_points)-1):
        draw.line([route_points[i], route_points[i+1]], fill=DARK_BLUE, width=6)
    
    # Walking person animation dots
    for i, point in enumerate(route_points[:-1]):
        if i == 1:  # Current position
            draw.ellipse([point[0]-8, point[1]-8, point[0]+8, point[1]+8], fill=DARK_BLUE)
    
    # Destination marker
    draw.ellipse([85, 145, 115, 175], fill=GREEN, outline=WHITE, width=3)
    draw.polygon([(90, 170), (110, 170), (100, 195)], fill=GREEN)
    draw.text((92, 152), "📍", fill=WHITE)
    
    # Your location
    draw.ellipse([185, 530, 215, 560], fill=DARK_BLUE, outline=WHITE, width=3)
    
    # Direction header
    draw.rounded_rectangle([40, 80, width-40, 150], radius=15, fill=WHITE)
    draw.text((60, 90), "↑ Head North", fill=DARK_BLUE)
    draw.text((60, 115), "Walk 50m to Admin Building", fill=GRAY)
    
    # Bottom info
    draw.rounded_rectangle([40, height-200, width-40, height-115], radius=15, fill=WHITE)
    draw.text((60, height-190), "2 min • 150m", fill=BLACK)
    draw.text((60, height-165), "Dr. Santos • Admin Building", fill=GRAY)
    
    # Arrival estimate
    draw.rounded_rectangle([width-120, height-190, width-55, height-160], radius=8, fill=GREEN)
    draw.text((width-110, height-182), "ETA", fill=WHITE)
    
    draw_bottom_nav(draw, width, height, active=1)
    
    return img

def create_privacy_settings():
    """Create Privacy Settings mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Header
    draw.rectangle([20, 60, width-20, 130], fill=DARK_BLUE)
    draw.text((40, 85), "← Privacy Settings", fill=WHITE)
    
    # Privacy controls
    settings = [
        ("Location Sharing", "Allow students to see your location", True),
        ("Auto-Off After Hours", "Disable at 5:00 PM daily", True),
        ("Campus Only", "Only share within campus bounds", True),
        ("Show Status", "Display availability status", True),
        ("Allow Messages", "Receive student queries", False),
    ]
    
    y = 150
    for title, desc, enabled in settings:
        draw.rounded_rectangle([40, y, width-40, y+80], radius=12, fill=WHITE)
        draw.text((60, y+15), title, fill=BLACK)
        draw.text((60, y+40), desc, fill=GRAY)
        
        # Toggle
        if enabled:
            draw.rounded_rectangle([width-110, y+25, width-60, y+55], radius=15, fill=GREEN)
            draw.ellipse([width-85, y+28, width-63, y+52], fill=WHITE)
        else:
            draw.rounded_rectangle([width-110, y+25, width-60, y+55], radius=15, fill=GRAY)
            draw.ellipse([width-107, y+28, width-85, y+52], fill=WHITE)
        
        y += 95
    
    # Privacy notice
    draw.rounded_rectangle([40, y+20, width-40, y+100], radius=12, fill=LIGHT_GREEN)
    draw.text((60, y+40), "🔒 Your privacy is protected", fill=GREEN)
    draw.text((60, y+65), "No location history is stored", fill=GRAY)
    
    draw_bottom_nav(draw, width, height, active=3)
    
    return img

def create_admin_dashboard():
    """Create Admin Dashboard mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), LIGHT_GRAY)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Header
    draw.rectangle([20, 60, width-20, 130], fill=DARK_BLUE)
    draw.text((40, 85), "UniTrack Admin", fill=WHITE)
    
    # Stats cards
    stats = [
        ("Faculty Online", "24", GREEN),
        ("Students Active", "156", DARK_BLUE),
    ]
    
    card_width = (width - 60) // 2
    for i, (label, value, color) in enumerate(stats):
        x = 40 + i * (card_width + 10)
        draw.rounded_rectangle([x, 145, x+card_width, 220], radius=12, fill=WHITE)
        draw.text((x+20, 160), value, fill=color)
        draw.text((x+20, 190), label, fill=GRAY)
    
    # Analytics preview
    draw.rounded_rectangle([40, 240, width-40, 380], radius=12, fill=WHITE)
    draw.text((60, 255), "📊 Today's Activity", fill=BLACK)
    
    # Simple bar chart
    hours = ["9AM", "12PM", "3PM", "Now"]
    values = [30, 80, 50, 65]
    bar_width = 50
    for i, (hour, val) in enumerate(zip(hours, values)):
        x = 70 + i * 75
        bar_height = val
        draw.rectangle([x, 360-bar_height, x+bar_width, 360], fill=GREEN)
        draw.text((x+15, 362), hour, fill=GRAY)
    
    # Department list
    draw.rounded_rectangle([40, 400, width-40, 580], radius=12, fill=WHITE)
    draw.text((60, 415), "📋 Departments", fill=BLACK)
    
    depts = [("IT Department", "12 online"), ("CS Department", "8 online"), ("Math Department", "5 online")]
    for i, (dept, count) in enumerate(depts):
        y = 450 + i * 40
        draw.text((60, y), dept, fill=BLACK)
        draw.text((width-120, y), count, fill=GREEN)
    
    # Quick actions
    draw.rounded_rectangle([40, 600, width-40, 680], radius=12, fill=WHITE)
    draw.text((60, 615), "Quick Actions", fill=BLACK)
    
    actions = ["+ Add User", "📊 Reports", "⚙️ Settings"]
    for i, action in enumerate(actions):
        x = 60 + i * 100
        draw.rounded_rectangle([x, 640, x+90, 670], radius=8, fill=LIGHT_BLUE)
        draw.text((x+10, 648), action, fill=DARK_BLUE)
    
    draw_bottom_nav(draw, width, height, active=0)
    
    return img

def create_login_screen():
    """Create Login Screen mockup"""
    width, height = 400, 800
    img = Image.new('RGB', (width, height), WHITE)
    draw = ImageDraw.Draw(img)
    
    draw_phone_frame(draw, width, height)
    
    # Logo area
    draw.ellipse([width//2-60, 150, width//2+60, 270], fill=GREEN, outline=DARK_BLUE, width=3)
    draw.text((width//2-45, 190), "UniTrack", fill=WHITE)
    
    # Tagline
    draw.text((width//2-80, 290), "Find Faculty. Save Time.", fill=GRAY)
    
    # Login form
    draw.text((60, 350), "Sign in with SKSU Email", fill=BLACK)
    
    # Email field
    draw.rounded_rectangle([40, 380, width-40, 430], radius=10, fill=LIGHT_GRAY)
    draw.text((60, 395), "📧 student@sksu.edu.ph", fill=GRAY)
    
    # Password field
    draw.rounded_rectangle([40, 450, width-40, 500], radius=10, fill=LIGHT_GRAY)
    draw.text((60, 465), "🔒 ••••••••••", fill=GRAY)
    
    # Login button
    draw.rounded_rectangle([40, 530, width-40, 585], radius=12, fill=GREEN)
    draw.text((width//2-30, 548), "Sign In", fill=WHITE)
    
    # Or divider
    draw.line([(40, 620), (width//2-30, 620)], fill=GRAY, width=1)
    draw.text((width//2-15, 612), "or", fill=GRAY)
    draw.line([(width//2+20, 620), (width-40, 620)], fill=GRAY, width=1)
    
    # Role selector
    draw.text((width//2-60, 650), "Continue as:", fill=GRAY)
    
    roles = ["Student", "Faculty"]
    for i, role in enumerate(roles):
        x = 80 + i * 140
        draw.rounded_rectangle([x, 680, x+100, 715], radius=8, outline=GREEN, width=2)
        draw.text((x+25, 690), role, fill=GREEN)
    
    return img

def create_all_mockups():
    """Generate all mockups and save them"""
    mockups_dir = "mockups"
    os.makedirs(mockups_dir, exist_ok=True)
    
    mockups = [
        ("01_login_screen.png", create_login_screen()),
        ("02_staff_dashboard.png", create_staff_dashboard()),
        ("03_student_directory.png", create_student_directory()),
        ("04_live_map.png", create_live_map()),
        ("05_navigation.png", create_navigation_screen()),
        ("06_privacy_settings.png", create_privacy_settings()),
        ("07_admin_dashboard.png", create_admin_dashboard()),
    ]
    
    paths = []
    for filename, img in mockups:
        path = os.path.join(mockups_dir, filename)
        img.save(path)
        paths.append(path)
        print(f"Created: {path}")
    
    return paths

if __name__ == "__main__":
    create_all_mockups()
    print("\n✅ All mockups created successfully!")
