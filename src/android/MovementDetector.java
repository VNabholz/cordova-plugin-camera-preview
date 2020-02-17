package com.cordovaplugincamerapreview;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

import org.apache.cordova.CordovaPlugin;

import java.util.HashSet;
import java.util.List;



public class MovementDetector extends CordovaPlugin implements SensorEventListener {

  protected final String TAG = getClass().getSimpleName();

  private SensorManager sensorMan;
  private Sensor accelerometer;

  private float x, y;                                // most recent acceleration values
  private int accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM;
  private int current_position;

  private MovementDetector() {
  }

  private static MovementDetector mInstance;

  public static MovementDetector getInstance(Context context) {
    if (mInstance == null) {
      mInstance = new MovementDetector();
      mInstance.init(context);
    }
    return mInstance;
  }

  //////////////////////
  private HashSet<Listener> mListeners = new HashSet<MovementDetector.Listener>();

  private void init(Context context) {
    sensorMan = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
    accelerometer = sensorMan.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION);
  }

  public void start() {
    // Get accelerometer from sensor manager
    List<Sensor> list = this.sensorMan.getSensorList(Sensor.TYPE_ACCELEROMETER);

    // If found, then register as listener
    if ((list != null) && (list.size() > 0)) {
      this.accelerometer = list.get(0);
      if (this.sensorMan.registerListener(this, this.accelerometer, SensorManager.SENSOR_DELAY_NORMAL)) {
        // CB-11531: Mark accuracy as 'reliable' - this is complementary to
        // setting it to 'unreliable' 'stop' method
        this.accuracy = SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM;
      }

    }
  }


  public void stop() {
    try {
      sensorMan.unregisterListener(this);
      mListeners.clear();
    } catch (Exception e) {

      Log.e(TAG, "Asta e cu eroare!");
      Log.e(TAG, e.getMessage());
    }
  }

  public void addListener(Listener listener) {
    mListeners.add(listener);
  }


  public static final int UPSIDE_DOWN = 3;
  public static final int LANDSCAPE_RIGHT = 4;
  public static final int PORTRAIT = 1;
  public static final int LANDSCAPE_LEFT = 2;
  public int mOrientationDeg; //last rotation in degrees
  public int mOrientationRounded; //last orientation int from above
  private static final int _DATA_X = 0;
  private static final int _DATA_Y = 1;
  private static final int _DATA_Z = 2;
  private int ORIENTATION_UNKNOWN = -1;

  @Override
  public void onSensorChanged(SensorEvent event) {
    float[] values = event.values;
    int orientation = ORIENTATION_UNKNOWN;
    float X = -values[_DATA_X];
    float Y = -values[_DATA_Y];
    float Z = -values[_DATA_Z];
    float magnitude = X * X + Y * Y;
    int tempOrientRounded = 0;

    // Don't trust the angle if the magnitude is small compared to the y value
    if (magnitude * 4 >= Z * Z) {
      float OneEightyOverPi = 57.29577957855f;
      float angle = (float) Math.atan2(-Y, X) * OneEightyOverPi;
      orientation = 90 - (int) Math.round(angle);

      // normalize to 0 - 359 range
      while (orientation >= 360) {
        orientation -= 360;
      }

      while (orientation < 0) {
        orientation += 360;
      }

    }

    //^^ thanks to google for that code
    //now we must figure out which orientation based on the degrees

    if (orientation != mOrientationDeg) {
      mOrientationDeg = orientation;
      //figure out actual orientation
      if (orientation == -1) {//basically flat
        tempOrientRounded = 1;//portrait
      } else if (orientation <= 45 || orientation > 315) {//round to 0
        tempOrientRounded = 1;//portrait
      } else if (orientation > 45 && orientation <= 135) {//round to 90
        tempOrientRounded = 4; //lsleft huawei
//        tempOrientRounded = 2; //lsleft samsung
      } else if (orientation > 135 && orientation <= 225) {//round to 180
        tempOrientRounded = 3; //upside down
      } else if (orientation > 225 && orientation <= 315) {//round to 270
        tempOrientRounded = 2;//lsright
//        tempOrientRounded = 4;//lsright
      }
    }


//    Log.e("ALEX_CAMERA", "Se apeleaza functia minute: " + String.valueOf((mOrientationRounded - 1) * 90));

    if (tempOrientRounded != 0 && mOrientationRounded != tempOrientRounded) {
      //Orientation changed, handle the change here
      mOrientationRounded = tempOrientRounded;
      for (Listener listener : mListeners) {
        Log.e("ALEX_CAMERA", "Astea sunt gradele pe care le da giroscopul - " + String.valueOf((mOrientationRounded - 1) * 90));
        listener.onMotionDetected((mOrientationRounded - 1) * 90);
      }
    }
  }

  /* (non-Javadoc)
   * @see android.hardware.SensorEventListener#onAccuracyChanged(android.hardware.Sensor, int)
   */
  @Override
  public void onAccuracyChanged(Sensor sensor, int accuracy) {
    // TODO Auto-generated method stub

  }

  public interface Listener {
    void onMotionDetected(int postion);
  }
}
