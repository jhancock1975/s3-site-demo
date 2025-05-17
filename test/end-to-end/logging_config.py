import logging
from datetime import datetime, timezone

# Configure logging with date and UTC time
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s UTC [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
# Use timezone.utc instead of the deprecated utcnow
def time_in_utc(*args):
    return datetime.now(timezone.utc).timetuple()

logging.Formatter.converter = time_in_utc