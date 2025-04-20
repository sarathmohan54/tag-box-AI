from sqlalchemy.orm import Session
from models import Category
from datetime import datetime

categories = [
    # Entertainment
    "Comedy", "Dance", "Music", "Movies", "TV Shows", "Gaming", "Sports", "Anime",
    
    # Lifestyle
    "Fashion", "Beauty", "Travel", "Food", "Cooking", "Fitness", "Health", "Wellness",
    "Home Decor", "DIY", "Crafts", "Gardening", "Pets", "Parenting",
    
    # Education
    "Educational", "Science", "Technology", "Programming", "Languages", "History",
    "Mathematics", "Literature", "Art", "Photography", "Design",
    
    # Business & Career
    "Business", "Entrepreneurship", "Marketing", "Finance", "Career Tips",
    "Personal Development", "Productivity", "Leadership",
    
    # Social Issues
    "News", "Politics", "Environment", "Social Justice", "Mental Health",
    "Motivation", "Inspiration",
    
    # Specific Content Types
    "Tutorials", "Reviews", "Reactions", "Challenges", "Pranks", "Vlogs",
    "Behind the Scenes", "Q&A", "Interviews", "Storytelling",
    
    # Specific Niches
    "ASMR", "Meditation", "Yoga", "Workout", "Recipe", "Makeup Tutorial",
    "Skincare", "Hair Care", "Fashion Tips", "Style Guide",
    
    # Creative Arts
    "Music Covers", "Dance Choreography", "Art Process", "Digital Art",
    "Traditional Art", "Animation", "Short Films", "Poetry", "Creative Writing",
    
    # Tech & Gaming
    "Tech Reviews", "Gaming Highlights", "Game Reviews", "Tech Tips",
    "Coding", "App Reviews", "Gadget Reviews", "Gaming Tutorials",
    
    # Lifestyle Subcategories
    "Morning Routine", "Night Routine", "Room Tour", "House Tour",
    "Organization", "Minimalism", "Sustainable Living", "Zero Waste",
    
    # Food & Cooking
    "Quick Recipes", "Healthy Recipes", "Baking", "Restaurant Reviews",
    "Food Reviews", "Street Food", "Cooking Tips", "Kitchen Hacks",
    
    # Fashion & Beauty
    "Outfit Ideas", "Fashion Hauls", "Makeup Looks", "Skincare Routine",
    "Hair Tutorials", "Fashion Trends", "Beauty Hacks", "Style Tips",
    
    # Travel & Adventure
    "Travel Tips", "Travel Vlogs", "Adventure Sports", "Hidden Gems",
    "Budget Travel", "Luxury Travel", "Road Trips", "Travel Hacks",
    
    # Fitness & Health
    "Workout Routines", "Diet Tips", "Weight Loss", "Muscle Building",
    "Yoga Flow", "Meditation Guide", "Health Tips", "Nutrition",
    
    # Entertainment Subcategories
    "Movie Reviews", "TV Show Recaps", "Celebrity News", "Music Reviews",
    "Concert Clips", "Festival Coverage", "Entertainment News",
    
    # Educational Content
    "Life Hacks", "Study Tips", "Language Learning", "History Facts",
    "Science Experiments", "Math Tricks", "Educational Games",
    
    # Business & Marketing
    "Social Media Tips", "Digital Marketing", "SEO Tips", "Business Strategy",
    "Startup Tips", "E-commerce", "Online Business", "Side Hustles"
]

def seed_categories(db: Session, user_id: int):
    """
    Seed the database with predefined categories
    """
    print(f"Seeding {len(categories)} categories...")
    
    for category_name in categories:
        # Check if category already exists for this user
        existing = db.query(Category).filter(
            Category.user_id == user_id,
            Category.name == category_name
        ).first()
        
        if not existing:
            category = Category(
                name=category_name,
                user_id=user_id,
                created_at=datetime.utcnow()
            )
            db.add(category)
    
    db.commit()
    print("Categories seeded successfully!") 