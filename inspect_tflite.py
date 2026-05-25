import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path="c:/Users/parth/Desktop/Student Attendance Management/student_attendance_app/assets/mobilefacenet.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input Details:")
for d in input_details:
    print(d['shape'], d['dtype'])

print("Output Details:")
for d in output_details:
    print(d['shape'], d['dtype'])
