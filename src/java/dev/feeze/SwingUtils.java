/*

This file is part of the Feeze scheduling analysis tool.

This code is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License, version 3,
as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License, version 3,
along with this program.  If not, see <http://www.gnu.org/licenses/>

*/

/*-----------------------------------------------------------------------
 *
 * Copyright (c) 2026, Tokiwa Software GmbH, Germany
 *
 * Java source code of class dev.feeze.SwingUtils
 *
 *---------------------------------------------------------------------*/


package dev.feeze;

import java.awt.event.ActionEvent;
import java.awt.event.KeyEvent;

import javax.swing.AbstractAction;
import javax.swing.JComponent;
import javax.swing.JFrame;
import javax.swing.KeyStroke;


/**
 * Utility methods for common Swing functionality.
 */
public class SwingUtils
{

  /**
   * Enables toggling fullscreen mode for the given frame using the F11 key.
   *
   * @param frame the frame to enable fullscreen toggling for
   */
  public static void enableFullscreenToggle(JFrame frame)
  {
    var root_pane = frame.getRootPane();

    root_pane.getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW)
      .put(
        KeyStroke.getKeyStroke(KeyEvent.VK_F11, 0),
        "toggleFullscreen"
      );

    root_pane.getActionMap()
      .put("toggleFullscreen", new AbstractAction()
      {
        @Override public void actionPerformed(ActionEvent e)
        {
          var device = frame.getGraphicsConfiguration().getDevice();

          device.setFullScreenWindow(
            device.getFullScreenWindow() == frame
              ? null
              : frame
          );
        }
      });
  }
  
}
