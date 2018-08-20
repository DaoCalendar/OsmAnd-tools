package net.osmand.server.services.images;

import java.util.List;

public class CameraPlaceCollection {

    private final List<CameraPlace> features;

    public CameraPlaceCollection(List<CameraPlace> features) {
        this.features = features;
    }

    public List<CameraPlace> getFeatures() {
        return features;
    }
}