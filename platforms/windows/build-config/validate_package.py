"""Validate the checked-in MSIX manifest without Windows-only dependencies."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

manifest = Path(__file__).parents[1] / "installer-windows" / "AppxManifest.xml"
root = ET.parse(manifest).getroot()
ns = {"f": "http://schemas.microsoft.com/appx/manifest/foundation/windows10"}
identity = root.find("f:Identity", ns)
apps = root.find("f:Applications", ns)
if identity is None or not identity.get("Name") or not identity.get("Version"):
    raise SystemExit("invalid package identity")
if apps is None or apps.find("f:Application", ns) is None:
    raise SystemExit("package has no application")
print("PACKAGE_MANIFEST_OK")
