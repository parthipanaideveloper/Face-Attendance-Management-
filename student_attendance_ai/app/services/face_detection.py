import face_recognition

class FaceDetectionService:
    @staticmethod
    def detect_faces(rgb_frame):
        """
        Analyzes an RGB frame and returns a list of bounding boxes 
        (top, right, bottom, left) of human faces found.
        """
        return face_recognition.face_locations(rgb_frame)
