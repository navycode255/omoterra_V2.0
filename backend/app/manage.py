"""Explicit development database initialization. Never called at API startup."""
from .db import Base, engine
from . import models  # noqa: F401
from .config import settings

if __name__ == '__main__':
    settings().validate_runtime()
    Base.metadata.create_all(engine)
    from .migrate_inventory import install_history_guards
    install_history_guards(engine)
    print('Omoterra development schema created.')
