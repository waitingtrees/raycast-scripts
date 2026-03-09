
import opentimelineio as otio
import os

def test_bin_export():
    # Create a collection (Bin)
    bin_collection = otio.schema.SerializableCollection(name="Master Bin")
    
    # Create a Master Clip
    media_path = "Test_Clip_01.mov"
    media_reference = otio.schema.ExternalReference(
        target_url=media_path,
        available_range=otio.opentime.TimeRange(
            start_time=otio.opentime.RationalTime(0, 24),
            duration=otio.opentime.RationalTime(100, 24)
        )
    )
    
    clip = otio.schema.Clip(
        name="Test Clip 01",
        media_reference=media_reference,
        source_range=otio.opentime.TimeRange(
            start_time=otio.opentime.RationalTime(0, 24),
            duration=otio.opentime.RationalTime(100, 24)
        )
    )
    
    bin_collection.append(clip)

    # Export to FCP XML
    output_path = "test_bin.xml"
    otio.adapters.write_to_file(bin_collection, output_path, adapter_name="fcp_xml")

    # Read back and print
    with open(output_path, 'r') as f:
        print(f.read())
    
    os.remove(output_path)

if __name__ == "__main__":
    test_bin_export()
