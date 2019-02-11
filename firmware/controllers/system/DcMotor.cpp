/**
 * @file DcMotor.cpp
 * @brief DC motor controller
 * 
 * @date Dec 22, 2018
 * @author Matthew Kennedy
 */

#include "DcMotor.h"

TwoPinDcMotor::TwoPinDcMotor(SimplePwm* pwm, OutputPin* dir1, OutputPin* dir2)
    : m_pwm(pwm)
    , m_dir1(dir1)
    , m_dir2(dir2)
{
}

/**
 * @param duty value between -1.0 and 1.0
 */
bool TwoPinDcMotor::Set(float duty)
{
    bool isPositiveOrZero;

    if(duty < 0)
    {
    	isPositiveOrZero = false;
        duty = -duty;
    }
    else
    {
    	isPositiveOrZero = true;
    }
    // below here 'duty' is a not negative

    // Clamp to 100%
    if(duty > 1.0f)
    {
        duty = 1.0f;
    }
    // Disable for very small duty
    else if (duty < 0.01f)
    {
        duty = 0.0f;
    }

    if(duty < 0.01f)
    {
        m_dir1->setValue(false);
        m_dir2->setValue(false);
    }
    else
    {
        m_dir1->setValue(isPositiveOrZero);
        m_dir2->setValue(!isPositiveOrZero);
    }

    m_pwm->setSimplePwmDutyCycle(duty);

    // This motor has no fault detection, so always return false (indicate success).
    return false;
}
