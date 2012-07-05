#
# ANDROID_ARCH
#  arm, x86, mips
# ANDROID_ABI
#  armeabi, armeabi-v7a, x86, mips
# ANDROID_TARGET
#  android-*
# ANDOIRD_WITH_NEON
# ANDOIRD_WITH_VFP
# ANDROID_WITH_STLPORT
# ANDROID_WITH_THUMB
# ANDROID_WITH_ARM
# 
GET_PROPERTY(_IN_TC GLOBAL PROPERTY IN_TRY_COMPILE)
IF(_IN_TC)
	return()
ENDIF()

# set default value
IF(NOT DEFINED CMAKE_SYSTEM_NAME)
	SET(CMAKE_SYSTEM_NAME "Linux")
ENDIF()

IF(NOT DEFINED ANDROID_ARCH)
	SET(ANDROID_ARCH "arm")
ENDIF()

IF(NOT DEFINED ANDROID_ABI)
	SET(ANDROID_ABI "armeabi")
ENDIF()

IF(NOT DEFINED ANDROID_TARGET)
	SET(ANDROID_TARGET "android-9")
ENDIF()

IF(NOT DEFINED ANDROID_WITH_NEON AND NOT DEFINED ANDROID_WITH_VFP)
	SET(ANDROID_WITH_NEON 1)
	SET(ANDROID_WITH_VFP 0)
ENDIF()

IF(NOT DEFINED ANDROID_WITH_STLPORT)
	SET(ANDROID_WITH_STLPORT 0)
ENDIF()

IF(NOT DEFINED ANDROID_WITH_THUMB AND NOT DEFINED ANDROID_WITH_ARM)
	SET(ANDROID_WITH_THUMB 0)
	SET(ANDROID_WITH_ARM 1)
ENDIF()

IF(NOT DEFINED ANDROID_NDK)
	SET(ANDROID_NDK "$ENV{ANDROID_NDK}")
ENDIF()

IF(NOT DEFINED ANDROID_NDK OR ANDROID_NDK STREQUAL "")
	MESSAGE(FATAL_ERROR "ANDROID_NDK is not defined or empty.")
ENDIF()

# get CMAKE_HOST_SYSTEM_NAME
IF(NOT CMAKE_HOST_SYSTEM_NAME)
	IF(CMAKE_HOST_UNIX)
		FIND_PROGRAM(CMAKE_UNAME uname /bin /usr/bin /usr/local/bin)
		IF(CMAKE_UNAME)
			EXEC_PROGRAM(uname ARGS -s OUTPUT_VARIABLE CMAKE_HOST_SYSTEM_NAME)
		ENDIF(CMAKE_UNAME)
	ENDIF(CMAKE_HOST_UNIX)
ENDIF(NOT CMAKE_HOST_SYSTEM_NAME)

# set ANDROID_HOST_SYSTEM_NAME
IF(CMAKE_HOST_APPLE)
	SET(ANDROID_HOST_SYSTEM_NAME "darwin-x86")
ELSEIF(CMAKE_HOST_WIN32)
	SET(ANDROID_HOST_SYSTEM_NAME "windows")
ELSEIF(CMAKE_HOST_UNIX)
	SET(ANDROID_HOST_SYSTEM_NAME "linux-x86")
ELSE()
	MESSAGE(FATAL_ERROR "Android cross-compilation on this platform is not supported.")
ENDIF()


IF(CMAKE_HOST_SYSTEM_NAME MATCHES "CYGWIN.*")
	SET(CMAKE_USE_RELATIVE_PATHS 1)

	# CMAKE_BINARY_DIR and CMAKE_ROOT should be converted to windows-style
	# they are used by TRY_COMPILE and CMAKE_DETERMINE_COMPILER_ABI
	EXEC_PROGRAM(cygpath ARGS -m -w ${CMAKE_BINARY_DIR} OUTPUT_VARIABLE CMAKE_BINARY_DIR)

	EXEC_PROGRAM(cygpath ARGS -m -w ${CMAKE_ROOT} OUTPUT_VARIABLE CMAKE_ROOT)

	STRING(REGEX REPLACE "\\\\" "/" ANDROID_NDK "${ANDROID_NDK}")
	EXEC_PROGRAM(cygpath ARGS -m -w ${ANDROID_NDK} OUTPUT_VARIABLE ANDROID_NDK)  

	SET(ANDROID_HOST_SYSTEM_NAME "windows")
ENDIF(CMAKE_HOST_SYSTEM_NAME MATCHES "CYGWIN.*")

# find available android targets
MACRO(FIND_AVAIABLE_TARGETS ANDROID_NDK)
	FILE(GLOB ANDROID_TARGETS RELATIVE "${ANDROID_NDK}/platforms" "${ANDROID_NDK}/platforms/android-*")
ENDMACRO(FIND_AVAIABLE_TARGETS)

# find available android abis
MACRO(FIND_AVAIABLE_ABIS ANDROID_NDK)
	SET(ANDROID_ARCHS "")
	FILE(GLOB TOOLCHAINS RELATIVE "${ANDROID_NDK}/toolchains" "${ANDROID_NDK}/toolchains/*")
	FOREACH(toolchain ${TOOLCHAINS})
		STRING(REGEX MATCH "[0-9]+.[0-9]+.[0-9]+$" _COMPILER_VERSION "${toolchain}")
		STRING(REGEX MATCH "^[^-]+" ARCH "${toolchain}")

		LIST(APPEND ANDROID_ARCHS "${ARCH}")
		SET(${ARCH}_ABIS "")
		SET(${ARCH}_TOOLCHAIN "${toolchain}")
		SET(${ARCH}_COMPILER_VERSION "${_COMPILER_VERSION}")

		FILE(READ "${ANDROID_NDK}/toolchains/${toolchain}/config.mk" content)
		STRING(REGEX REPLACE ".*TOOLCHAIN_ABIS[ \t]*:=[ \t]*([^\n\r]*).*" "\\1" abis "${content}")
		STRING(REGEX REPLACE "[ \t]" ";" abis "${abis}")

		LIST(APPEND ${ARCH}_ABIS "${abis}")
	ENDFOREACH()
ENDMACRO(FIND_AVAIABLE_ABIS)

# check android target
FUNCTION(CHECK_ANDROID_TARGET)
LIST(FIND ANDROID_TARGETS "${ANDROID_TARGET}" idx)
IF(idx EQUAL -1)
	STRING(REPLACE ";" "\", \"" _val  "${ANDROID_TARGETS}")
	MESSAGE(FATAL_ERROR "ANDROID_TARGET = \"${ANDROID_TARGET}\" is not supported, candicate are: \n\"${_val}\" ")
ENDIF(idx EQUAL -1)
ENDFUNCTION(CHECK_ANDROID_TARGET)

# check android arch
FUNCTION(CHECK_ANDROID_ARCH)
LIST(FIND ANDROID_ARCHS "${ANDROID_ARCH}" idx)
IF(idx EQUAL -1)
	STRING(REPLACE ";" "\", \"" _val  "${ANDROID_ARCHS}")
	MESSAGE(FATAL_ERROR "ANDROID_ARCH = \"${ANDROID_ARCH}\" is not supported, candicate are: \n\"${_val}\" ")
ENDIF(idx EQUAL -1)
ENDFUNCTION(CHECK_ANDROID_ARCH)

# check android abi
FUNCTION(CHECK_ANDROID_ABI)
LIST(FIND ${ANDROID_ARCH}_ABIS "${ANDROID_ABI}" idx)
IF(idx EQUAL -1)
	STRING(REPLACE ";" "\", \"" _val  "${${ANDROID_ARCH}_ABIS}")
	MESSAGE(FATAL_ERROR "ANDROID_ABI = \"${ANDROID_ABI}\" is not supported, candicate are: \n\"${_val}\" ")
ENDIF(idx EQUAL -1)
ENDFUNCTION(CHECK_ANDROID_ABI)

FIND_AVAIABLE_TARGETS(${ANDROID_NDK})
FIND_AVAIABLE_ABIS(${ANDROID_NDK})
CHECK_ANDROID_TARGET()
CHECK_ANDROID_ARCH()
CHECK_ANDROID_ABI()

# set ANDROID_ABI_NAME
IF(ANDROID_ARCH STREQUAL "arm")
	SET(ANDROID_ABI_NAME "arm-linux-androideabi")
ELSEIF (ANDROID_ARCH STREQUAL "x86")
	SET(ANDROID_ABI_NAME "i686-android-linux")
ELSEIF (ANDROID_ARCH STREQUAL "mipsel")
	SET(ANDROID_ABI_NAME "mipsel-linux-android")
ENDIF()

# set ANDROID_SYSROOT
SET(ANDROID_SYSROOT "${ANDROID_NDK}/platforms/${ANDROID_TARGET}/arch-${ANDROID_ARCH}")  

# set _CMAKE_USER_CXX_COMPILER_PATH and _CMAKE_TOOLCHAIN_PREFIX, so compiler can be found.
SET(_CMAKE_USER_CXX_COMPILER_PATH "${ANDROID_NDK}/toolchains/${${ANDROID_ARCH}_TOOLCHAIN}/prebuilt/${ANDROID_HOST_SYSTEM_NAME}/bin")
SET(_CMAKE_TOOLCHAIN_PREFIX "${ANDROID_ABI_NAME}-")

# stl 
IF(ANDROID_WITH_STLPORT)
	SET(STL_INCLUDE_PATH "${ANDROID_NDK}/sources/cxx-stl/stlport/stlport")
	SET(STL_LIB_PATH "${ANDROID_NDK}/sources/cxx-stl/stlport/libs/${ANDROID_ABI}")
ELSE()
	SET(STL_INCLUDE_PATH "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/include")
	SET(STL_LIB_PATH "${ANDROID_NDK}/sources/cxx-stl/gnu-libstdc++/libs/${ANDROID_ABI}")
ENDIF()

LIST(APPEND ANDROID_INCLUDE_DIRS "${STL_INCLUDE_PATH}")
LIST(APPEND ANDROID_LIB_DIRS "${STL_LIB_PATH}")

# EXECUTABLE_OUTPUT_PATH
IF(EXISTS "${CMAKE_SOURCE_DIR}/jni/CMakeLists.txt")
	SET(EXECUTABLE_OUTPUT_PATH "${CMAKE_SOURCE_DIR}/bin/${ANDROID_ABI}" CACHE PATH "Output directory for applications")
ENDIF()


SET(ANDROID_TARGET_SPECIFIC  "${ANDROID_NDK}/toolchains/${${ANDROID_ARCH}_TOOLCHAIN}/prebuilt/${ANDROID_HOST_SYSTEM_NAME}/lib/gcc/${ANDROID_ABI_NAME}/${${ARCH}_COMPILER_VERSION}")

LIST(APPEND ANDROID_INCLUDE_DIRS "${ANDROID_TARGET_SPECIFIC}/include" "${ANDROID_TARGET_SPECIFIC}/include-fixed")
IF(ANDROID_ARCH STREQUAL "arm")
	IF(ANDROID_ABI STREQUAL "armeabi-v7a")
		list(APPEND ANDROID_LIB_DIRS "${ANDROID_TARGET_SPECIFIC}/lib/${ANDROID_ABI}")
	ELSE()
		list(APPEND ANDROID_LIB_DIRS "${ANDROID_TARGET_SPECIFIC}/lib")
	ENDIF()
ELSEIF (ANDROID_ARCH STREQUAL "x86")
	list(APPEND ANDROID_LIB_DIRS "${ANDROID_TARGET_SPECIFIC}/lib")
ENDIF()

# check ANDROID_NO_UNDEFINED
IF(ANDROID_NO_UNDEFINED)
	SET(ANDROID_NO_UNDEFINED 0)
ENDIF()
SET(ANDROID_NO_UNDEFINED ${ANDROID_NO_UNDEFINED} CACHE BOOL "Show all undefined symbols as linker errors" FORCE)
MARK_AS_ADVANCED(ANDROID_NO_UNDEFINED)

SET(ANDROID_LANG_FLAGS "--sysroot='${ANDROID_SYSROOT}' -DANDROID")
SET(ANDROID_LD_FLAGS "--sysroot='${ANDROID_SYSROOT}'")

IF (ANDROID_ARCH STREQUAL "arm")
	SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -fpic -ffunction-sections -funwind-tables") #  -fstack-protector will cause " ld.exe: cannot find -lssp_nonshared"
	SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -D__ARM_ARCH_5__ -D__ARM_ARCH_5T__ -D__ARM_ARCH_5E__ -D__ARM__5TE__")  
	SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -Wno-psabi")  
	IF(ANDROID_ABI STREQUAL "armeabi-v7a")
		SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -march=armv7-a -mfloat-abi=softfp")  
		IF(ANDROID_WITH_NEON)
			SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -mfpu=vfp")
		ELSEIF(ANDROID_WITH_NEON)
			SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -mfpu=neon")
		ENDIF()
		SET(ANDROID_LD_FLAGS "${ANDROID_LD_FLAGS} -Wl,--fix-cortex-a8")
	ELSE()
		SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -march=armv5te -mtune=xscale -msoft-float")
	ENDIF()

	IF(ANDROID_NO_UNDEFINED)
		SET(ANDROID_LD_FLAGS "${ANDROID_LD_FLAGS} -Wl,--no-undefined ")
	ENDIF()

	IF(ANDROID_WITH_ARM)
		SET(ANDROID_LANG_FLAGS_INIT "${ANDROID_LANG_FLAGS}")
		SET(ANDROID_LANG_FLAGS_DEBUG_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300 -fno-omit-frame-pointer -fno-strict-aliasing")
		SET(ANDROID_LANG_FLAGS_MINSIZEREL_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300")
		SET(ANDROID_LANG_FLAGS_RELEASE_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300")
		SET(ANDROID_LANG_FLAGS_RELWITHDEBINFO_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300 -g")
	ELSE()
		SET(ANDROID_LANG_FLAGS_INIT "${ANDROID_LANG_FLAGS}")
		SET(ANDROID_LANG_FLAGS_DEBUG_INIT "-mthumb -Os -fomit-frame-pointer -fno-strict-aliasing -finline-limit=64 -marm -fno-omit-frame-pointer")
		SET(ANDROID_LANG_FLAGS_MINSIZEREL_INIT "-mthumb -Os -fomit-frame-pointer -fno-strict-aliasing -finline-limit=64")
		SET(ANDROID_LANG_FLAGS_RELEASE_INIT "-mthumb -Os -fomit-frame-pointer -fno-strict-aliasing -finline-limit=64")
		SET(ANDROID_LANG_FLAGS_RELWITHDEBINFO_INIT "-mthumb -O2 -fomit-frame-pointer -fno-strict-aliasing -finline-limit=64 -g")
	ENDIF()
	SET(CMAKE_EXE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -Wl,--gc-sections -Wl,-z,nocopyreloc")
	SET(CMAKE_MODULE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} ")
	SET(CMAKE_SHARED_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -shared")  
ELSEIF(ANDROID_ARCH STREQUAL "x86")
	SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -ffunction-sections -funwind-tables")
	SET(ANDROID_LANG_FLAGS_INIT "${ANDROID_LANG_FLAGS}")
	SET(ANDROID_LANG_FLAGS_DEBUG_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300 -fno-omit-frame-pointer -fno-strict-aliasing")
	SET(ANDROID_LANG_FLAGS_MINSIZEREL_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300")
	SET(ANDROID_LANG_FLAGS_RELEASE_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300")
	SET(ANDROID_LANG_FLAGS_RELWITHDEBINFO_INIT "-O2 -fomit-frame-pointer -fstrict-aliasing -funswitch-loops -finline-limit=300 -g")
	SET(CMAKE_EXE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -Wl,--gc-sections -Wl,-z,nocopyreloc")
	SET(CMAKE_MODULE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} ")
	SET(CMAKE_SHARED_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -shared")  
ELSEIF(ANDROID_ARCH STREQUAL "mips" OR ANDROID_ARCH STREQUAL "mipsel")
	SET(ANDROID_LANG_FLAGS "${ANDROID_LANG_FLAGS} -fpic -fno-strict-aliasing -finline-functions -ffunction-sections -funwind-tables -fmessage-length=0 -fno-inline-functions-called-once -fgcse-after-reload -frerun-cse-after-loop -frename-registers -Wno-psabi")
	SET(ANDROID_LANG_FLAGS_INIT "${ANDROID_LANG_FLAGS}")
	SET(ANDROID_LANG_FLAGS_DEBUG_INIT "-O0 -g -fno-omit-frame-pointer")
	SET(ANDROID_LANG_FLAGS_MINSIZEREL_INIT "-O2 -fomit-frame-pointer -funswitch-loops -finline-limit=300")
	SET(ANDROID_LANG_FLAGS_RELEASE_INIT "-O2 -fomit-frame-pointer -funswitch-loops -finline-limit=300")
	SET(ANDROID_LANG_FLAGS_RELWITHDEBINFO_INIT "-O2 -fomit-frame-pointer -funswitch-loops -finline-limit=300-g")
	SET(CMAKE_EXE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -Wl,--gc-sections -Wl,-z,nocopyreloc")
	SET(CMAKE_MODULE_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} ")
	SET(CMAKE_SHARED_LINKER_FLAGS_INIT "${ANDROID_LD_FLAGS} -shared")
ENDIF()

# override __compiler_gnu to prevent reset flags.
macro(__compiler_gnu lang)
	# Feature flags.
	set(CMAKE_${lang}_VERBOSE_FLAG "-v")
	set(CMAKE_SHARED_LIBRARY_${lang}_FLAGS "-fPIC")
	set(CMAKE_SHARED_LIBRARY_CREATE_${lang}_FLAGS "-shared")

	# Initial configuration flags.
	set(CMAKE_${lang}_FLAGS_INIT "${ANDROID_LANG_FLAGS_INIT}")
	set(CMAKE_${lang}_FLAGS_DEBUG_INIT "${ANDROID_LANG_FLAGS_DEBUG_INIT}")
	set(CMAKE_${lang}_FLAGS_MINSIZEREL_INIT "${ANDROID_LANG_FLAGS_MINSIZEREL_INIT}")
	set(CMAKE_${lang}_FLAGS_RELEASE_INIT "${ANDROID_LANG_FLAGS_RELEASE_INIT}")
	set(CMAKE_${lang}_FLAGS_RELWITHDEBINFO_INIT "${ANDROID_LANG_FLAGS_RELWITHDEBINFO_INIT}")
	set(CMAKE_${lang}_CREATE_PREPROCESSED_SOURCE "<CMAKE_${lang}_COMPILER> <DEFINES> <FLAGS> -E <SOURCE> > <PREPROCESSED_SOURCE>")
	set(CMAKE_${lang}_CREATE_ASSEMBLY_SOURCE "<CMAKE_${lang}_COMPILER> <DEFINES> <FLAGS> -S <SOURCE> -o <ASSEMBLY_SOURCE>")
	if(NOT APPLE)
		set(CMAKE_INCLUDE_SYSTEM_FLAG_${lang} "-isystem ")
	endif(NOT APPLE)
endmacro()

SET(__COMPILER_GNU 1)

SET(ANDROID_ARCH "${ANDROID_ARCH}" CACHE STRING "Select architecture")
SET(ANDROID_ABI "${ANDROID_ABI}" CACHE STRING "Select ABI")
SET(ANDROID_TARGET "${ANDROID_TARGET}" CACHE STRING "Select target platform")
SET(ANDOIRD_WITH_NEON "${ANDOIRD_WITH_NEON}" CACHE STRING "Enable NEON optimizations")
SET(ANDOIRD_WITH_VFP "${ANDOIRD_WITH_VFP}" CACHE STRING "Enable VFP optimizations")
SET(ANDROID_WITH_STLPORT "${ANDROID_WITH_STLPORT}" CACHE STRING "Enable STLPORT library")
SET(ANDROID_WITH_THUMB "${ANDROID_WITH_THUMB}" CACHE STRING "Enable thumb instructions")
SET(ANDROID_WITH_ARM "${ANDROID_WITH_ARM}" CACHE STRING "Enable arm instructions")
SET(ANDROID_SYSROOT "${ANDROID_SYSROOT}" CACHE STRING "Enable arm instructions")
