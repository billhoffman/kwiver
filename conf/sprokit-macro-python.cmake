# Python functions for the sprokit project
# The following functions are defined:
#
#   sprokit_add_python_library
#   sprokit_add_python_module
#   sprokit_create_python_init
#   sprokit_create_python_plugin_init
#
# The following variables may be used to control the behavior of the functions:
#
#   sprokit_python_subdir
#     The subdirectory to use for Python modules (e.g., python2.7).
#
#   sprokit_python_output_path
#     The base output path for Python modules and libraries.
#
#   copyright_header
#     The copyright header to place at the top of generated __init__.py files.
#
#   python_both_arch
#     If set, __init__.py file is created for both the archful and pure-Python
#     module paths (if in doubt, you probably don't need this; it's necessary
#     to support CPython and pure Python sprokit plugins).
#
# Their syntax is:
#
#   sprokit_add_python_library(name modpath [source ...])
#     Builds and installs a library to be used as a Python module which may be
#     imported. It is built as a shared library, installed (use no_install to
#     not install the module), placed into the proper subdirectory but not
#     exported. Any other control variables for sprokit_add_library are
#     available.
#
#   sprokit_add_python_module(name modpath module)
#     Installs a pure-Python module into the 'modpath' and puts it into the
#     correct place in the build tree so that it may be used with any built
#     libraries in any build configuration.
#
#   sprokit_create_python_init(modpath [module ...])
#     Creates an __init__.py package file which imports the modules in the
#     arguments for the package.
#
#   sprokit_create_python_plugin_init(modpath)
#     Creates an __init__.py for use as a plugin package (packages for sprokit
#     plugins written in Python must use one of these files as the package
#     __init__.py file and added to the SPROKIT_PYTHON_MODULES environment
#     variable).

add_custom_target(python)

source_group("Python Files"
  REGULAR_EXPRESSION ".*\\.py\\.in$")
source_group("Python Files"
  REGULAR_EXPRESSION ".*\\.py$")

macro (_sprokit_create_safe_modpath    modpath    result)
  string(REPLACE "/" "." "${result}" "${modpath}")
endmacro ()

#
# Get canonical directory for python site packages.
# It varys from system to system.
#
function ( _sprokit_python_site_package_dir    var_name)
  execute_process(
  COMMAND "${PYTHON_EXECUTABLE}" -c "import distutils.sysconfig; print distutils.sysconfig.get_python_lib(prefix='')"
  RESULT_VARIABLE proc_success
  OUTPUT_VARIABLE python_site_packages
  )

# Returns something like
# "lib/python2.7/dist-packages"

if(NOT ${proc_success} EQUAL 0)
    message(FATAL_ERROR "Request for python site-packages location failed with error code: ${proc_success}")
  else()
    string(STRIP "${python_site_packages}" python_site_packages)
  endif()

  string( REGEX MATCH "dist-packages" result ${python_site_packages} )
  if (result)
    set( python_site_packages dist-packages)
  else()
    set( python_site_packages site-packages)
  endif()

  set( ${var_name} ${python_site_packages} PARENT_SCOPE )

endfunction()

function (sprokit_add_python_library    name    modpath)
  _sprokit_create_safe_modpath("${modpath}" safe_modpath)

  _sprokit_python_site_package_dir( python_site_packages )

  set(library_subdir "/${sprokit_python_subdir}")
  set(library_subdir_suffix "/${python_site_packages}/${modpath}")
  set(component runtime)

  set(no_export ON)

  sprokit_add_library("python-${safe_modpath}-${name}" MODULE
    ${ARGN})

  set(pysuffix "${CMAKE_SHARED_MODULE_SUFFIX}")
  if (WIN32 AND NOT CYTWIN)
    set(pysuffix .pyd)
  endif ()

  set_target_properties("python-${safe_modpath}-${name}"
    PROPERTIES
      OUTPUT_NAME "${name}"
      PREFIX      ""
      SUFFIX      "${pysuffix}")

  add_dependencies(python
    "python-${safe_modpath}-${name}")
endfunction ()

function (_sprokit_add_python_module    path     modpath    module)
  _sprokit_create_safe_modpath("${modpath}" safe_modpath)

  #
  # The output contains a full path, but sprokit may be configured to place
  # modules in a different location.
  #
  _sprokit_python_site_package_dir( python_site_packages )
  set(python_sitepath /${python_site_packages})

  set(python_arch)
  set(python_noarchdir)

  if (WIN32)
    set(python_install_path bin)
  else ()
    if (python_noarch)
      set(python_noarchdir /noarch)
      set(python_install_path lib)
      set(python_arch u)
    else ()
      set(python_install_path "lib${LIB_SUFFIX}")
    endif ()
  endif ()

  if (CMAKE_CONFIGURATION_TYPES)
    set(sprokit_configure_cmake_args
      "\"-Dconfig=${CMAKE_CFG_INTDIR}/\"")
    set(sprokit_configure_extra_dests
      "${sprokit_python_output_path}/${python_noarchdir}\${config}${python_sitepath}/${modpath}/${module}.py")
  endif ()
  sprokit_configure_file("python${python_arch}-${safe_modpath}-${module}"
    "${path}"
    "${sprokit_python_output_path}${python_noarchdir}${python_sitepath}/${modpath}/${module}.py"
    PYTHON_EXECUTABLE)

  sprokit_install(
    FILES       "${sprokit_python_output_path}${python_noarchdir}${python_sitepath}/${modpath}/${module}.py"
    DESTINATION "${python_install_path}/${sprokit_python_subdir}${python_sitepath}/${modpath}"
    COMPONENT   runtime)

  add_dependencies(python
    "configure-python${python_arch}-${safe_modpath}-${module}")

  if (python_both_arch)
    set(python_both_arch)
    set(python_noarch TRUE)

    if (NOT WIN32)
      _sprokit_add_python_module(
        "${path}"
        "${modpath}"
        "${module}")
    endif ()
  endif ()
endfunction ()

function (sprokit_add_python_module   path   modpath   module)
  _sprokit_add_python_module("${path}"
    "${modpath}"
    "${module}")
endfunction ()

function (sprokit_create_python_init modpath)
  _sprokit_create_safe_modpath("${modpath}" safe_modpath)

  set(init_template "${CMAKE_CURRENT_BINARY_DIR}/${safe_modpath}.__init__.py")

  if (NOT copyright_header)
    set(copyright_header "# Generated by sprokit")
  endif ()

  file(WRITE "${init_template}"
    "${copyright_header}\n\n")

  foreach (module IN LISTS ARGN)
    file(APPEND "${init_template}"
      "from ${module} import *\n")
  endforeach ()

  _sprokit_add_python_module("${init_template}"
    "${modpath}"
    __init__)
endfunction ()

function (sprokit_create_python_plugin_init modpath)
  _sprokit_create_safe_modpath("${modpath}" safe_modpath)

  set(init_template "${CMAKE_CURRENT_BINARY_DIR}/${safe_modpath}.__init__.py")

  if (NOT copyright_header)
    set(copyright_header "# Generated by sprokit")
  endif ()

  file(WRITE "${init_template}"
    "${copyright_header}\n\n")
  file(APPEND "${init_template}"
    "from pkgutil import extend_path\n")
  file(APPEND "${init_template}"
    "__path__ = extend_path(__path__, __name__)\n")

  _sprokit_add_python_module("${init_template}"
    "${modpath}"
    __init__)
endfunction ()
