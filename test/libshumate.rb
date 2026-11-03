# frozen_string_literal: true

# Released under the Apache License, Version 2.0.
# Copyright, 2026, by General Intelligence Systems.

require "libshumate"

describe Shumate do
  it "defines the namespace from the typelib" do
    # Not an arbitrary number: it is the point of the loader. A hand-written
    # binding exposes what someone got round to wrapping; this exposes what
    # libshumate has, which is 56 constants against this typelib. A drop to
    # single digits means the loader half-ran.
    expect(Shumate.constants.size).to be > 40
  end

  it "defines the classes a caller actually reaches for" do
    expect(Shumate.const_defined?(:Map)).to be == true
    expect(Shumate.const_defined?(:SimpleMap)).to be == true
    expect(Shumate.const_defined?(:MapSource)).to be == true
    expect(Shumate.const_defined?(:MapSourceRegistry)).to be == true
    expect(Shumate.const_defined?(:Viewport)).to be == true
    expect(Shumate.const_defined?(:Coordinate)).to be == true
    expect(Shumate.const_defined?(:Marker)).to be == true
    expect(Shumate.const_defined?(:MapLayer)).to be == true
  end

  it "constructs a coordinate and reads back what it was given" do
    # Shumate::Coordinate is a plain GObject rather than a widget, so it needs
    # neither a display nor a main loop. If the typelib's constructor had not
    # been mapped this raises; if the properties had not been, the reads come
    # back nil.
    coordinate = Shumate::Coordinate.new(51.5, -0.12)

    expect(coordinate.latitude).to be == 51.5
    expect(coordinate.longitude).to be == -0.12
  end

  it "round-trips a GObject property" do
    viewport = Shumate::Viewport.new
    viewport.zoom_level = 7.0

    expect(viewport.zoom_level).to be == 7.0
  end

  it "maps instance methods onto a class, not just constants" do
    # A loader that registered the types but defined no methods would still
    # satisfy every constant assertion above, so this is the one that catches a
    # half-loaded namespace. Shumate::Viewport carries 46 of its own against
    # this typelib.
    expect((Shumate::Viewport.instance_methods - Object.instance_methods).size).to be > 20
  end

  it "loads classes that descend from GObject" do
    # The typelib describes GObject types, so what the loader produces should
    # be GLib::Object subclasses rather than bare Ruby classes.
    expect(Shumate::Viewport.ancestors).to be(:include?, GLib::Object)
  end
end
