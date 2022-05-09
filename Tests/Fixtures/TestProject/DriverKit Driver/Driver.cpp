//
//  Driver.cpp
//  Driver
//
//  Created by Vlad Gorlov on 18.06.21.
//

#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>

#include "Driver.h"

kern_return_t
IMPL(Driver, Start)
{
    kern_return_t ret;
    ret = Start(provider, SUPERDISPATCH);
    os_log(OS_LOG_DEFAULT, "Hello World");
    return ret;
}
