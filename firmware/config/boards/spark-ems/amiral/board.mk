# Spark EMS Amiral - board makefile
#
# Hardware base: Hellen Mega-Module 176 (AlphaX-8chan derived open hardware),
# STM32F7 only. See docs/spark-ems/hardware-amiral.md

# Target ECU board design
BOARDCPPSRC = $(BOARD_DIR)/board_configuration.cpp

# SENT
DDEFS += -DSTM32_ICU_USE_TIM1=TRUE -DSTM32_PWM_USE_TIM1=FALSE
DDEFS += -DEFI_SENT_SUPPORT=TRUE

# TLS115_PG
DDEFS += -DDIAG_5VP_PIN=Gpio::MM176_OUT_PWM10

LED_CRITICAL_ERROR_BRAIN_PIN = -DLED_CRITICAL_ERROR_BRAIN_PIN=H176_MCU_MEGA_LED1_RED
include $(BOARDS_DIR)/hellen/hellen-common-mega176.mk

ifeq ($(PROJECT_CPU),ARCH_STM32F7)
	include $(PROJECT_DIR)/hw_layer/ports/stm32/2mb_flash.mk
	DDEFS += -DCH_DBG_ENABLE_ASSERTS=FALSE
	DDEFS += -DENABLE_PERF_TRACE=FALSE
else
$(error Spark EMS Amiral is STM32F7 only, got PROJECT_CPU [$(PROJECT_CPU)])
endif

# Same silicon layout as the 8chan mega-176 module: keep the shared code paths alive
DDEFS += -DHW_HELLEN_8CHAN=1

# Spark EMS product identification - use this for Amiral-specific code paths
DDEFS += -DHW_SPARK_EMS_AMIRAL=1

DDEFS += -DLUA_STM32_STANDBY=1

DDEFS += -DBOARD_SERIAL="\"000230000000000000000000\""

# watchdog suddenly i see it #8699
DDEFS += -DHAL_USE_WDG=FALSE
