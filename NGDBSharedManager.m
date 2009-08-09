/*
 * Copyright (c) 2009 Mo McRoberts.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 3. The names of the author(s) of this software may not be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * AUTHORS OF THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "p_ngdatabase.h"	

static NGDBSharedManager *sharedDatabaseManager;

@implementation NGDBSharedManager
{
	NSMutableDictionary *driverInfo;
	NSMutableDictionary *driverClasses;
}

+ (NGDBSharedManager *)sharedDatabaseManager
{
	@synchronized(self) {
        if (sharedDatabaseManager == nil) {
            [[self alloc] init];
        }
    }
	return sharedDatabaseManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedDatabaseManager == nil) {
            return [super allocWithZone:zone];
        }
    }
    return sharedDatabaseManager;
}

- (BOOL)loadPlugIns
{
	/* We attempt to load plug-ins from the following locations:
	 *
	 * <main bundle>/Contents/PlugIns
	 * <domain>/Library/Application Support/NGDatabase/PlugIns
	 *
	 * All plug-ins have the filename extension ".dbplugin", so as not
	 * to clash with plug-ins belonging to the application itself or
	 * other frameworks.
	 */
	NSBundle *mainBundle;
	NSEnumerator *en;
	NSArray *libpaths;
	NSMutableArray *paths;
	NSString *dir;
	
	paths = [[NSMutableArray alloc] init];
	libpaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
	en = [libpaths objectEnumerator];
	while((dir = [en nextObject]))
	{
		[paths addObject:[dir stringByAppendingPathComponent:@"Application Support/NGDatabase/PlugIns"]];
	}
	if((mainBundle = [NSBundle mainBundle]))
	{
		[paths addObject:[mainBundle builtInPlugInsPath]];
	}
	en = [paths objectEnumerator];
	while((dir = [en nextObject]))
	{
		[self loadDriversFromPath:dir];
	}
	[paths release];
	return YES;
}

- (id)init
{
    Class me = [self class];
    @synchronized(me) {
        if (sharedDatabaseManager == nil) {
            if (self = [super init]) {
                sharedDatabaseManager = self;
				driverClasses = [[NSMutableDictionary alloc] initWithCapacity:16];
				driverInfo = [[NSMutableDictionary alloc] initWithCapacity:16];
				/* Register the baked-in classes */
				[self addDriverClass:[NSDictionary dictionaryWithObjectsAndKeys:
									  @"com.nexgenta.NGDatabase.SQLite", @"CFBundleIdentifier",
									  @"© 2009 Mo McRoberts.", @"NSHumanReadableCopyright",
									  @"1.0", @"CFBundleVersion",
									  @"SQLite", @"CFBundleName",
									  @"English", @"CFBundleDevelopmentRegion",
									  [NSArray arrayWithObjects:
									   [NSDictionary dictionaryWithObjectsAndKeys:
										[NSArray arrayWithObjects:@"sqlite", @"sqlite3", nil], @"CFBundleURLSchemes", nil
										], nil], @"CFBundleURLTypes",
									  nil] class:NSClassFromString(@"NGSQLiteConnection") bundlePath:nil];
				/* Load any plug-in bundles that we might find */
				[self loadPlugIns];
            }
        }
    }
    return sharedDatabaseManager;
}

- (BOOL)addDriverClass:(NSDictionary *)infoDictionary class:(Class)theClass bundlePath:(NSString *)path
{
	NSMutableDictionary *infoDict;
	NSString *className;
	id urltypes, urldict, schemes, scheme;
	size_t c, d, count;
	
	if(!(urltypes = [infoDictionary objectForKey:@"CFBundleURLTypes"]) || ![urltypes isKindOfClass:[NSArray class]])
	{
		NSLog(@"NGDBSharedManager -addDriverClass:forScheme: CFBundleURLTypes key is absent");
		return NO;
	}
	if(!theClass)
	{
		if(!(className = [infoDictionary objectForKey:@"NSPrincipalClass"]))
		{
			NSLog(@"NGDBSharedManager -addDriverClass:forScheme: NSPrincipalClass key is absent");
			return NO;
		}
		if(!(theClass = NSClassFromString(className)))
		{
			NSLog(@"NGDBSharedManager -addDriverClass:forScheme: specified NSPrincipalClass (%@) does not exist", className);
			return NO;
		}
	}
	count = 0;
	infoDict = [[NSMutableDictionary alloc] initWithDictionary:infoDictionary];
	if(path)
	{
		[infoDict setObject:path forKey:@"NGBundlePath"];
	}
	for(c = 0; c < [urltypes count]; c++)
	{
		urldict = [urltypes objectAtIndex:c];
		if(![urldict isKindOfClass:[NSDictionary class]])
		{
			continue;
		}
		if(!(schemes = [urldict objectForKey:@"CFBundleURLSchemes"]) || ![urltypes isKindOfClass:[NSArray class]])
		{
			continue;
		}
		for(d = 0; d < [schemes count]; d++)
		{
			scheme = [schemes objectAtIndex:d];
			[driverClasses setObject:theClass forKey:scheme];
			[driverInfo setObject:infoDict forKey:scheme];
			count++;
		}
	}
	[infoDict release];
	if(count)
	{
		return YES;
	}
	NSLog(@"NGDBSharedManager -addDriverClass:forScheme: no URL schemes found to register");
	return NO;
}

- (Class)driverForScheme:(NSString *)scheme
{
	return (Class) [driverClasses objectForKey:scheme];
}

- (id)driverProperty:(NSString *)propertyName forScheme:(NSString *)scheme
{
	NSDictionary *dict;
	id prop;
	
	if((dict = [driverInfo objectForKey:scheme]))
	{
		if((prop = [dict objectForKey:propertyName]))
		{
			return prop;
		}
	}
	return nil;
}

- (NSDictionary *)driverInfoDictionaryForScheme:(NSString *)scheme
{
	NSDictionary *dict;
	
	if((dict = [driverInfo objectForKey:scheme]))
	{
		return dict;
	}
	return nil;
}

- (BOOL)loadDriversFromPath:(NSString *)folderPath
{
	NSDirectoryEnumerator *en;
	NSString *p;
	
	if(!(en = [[NSFileManager defaultManager] enumeratorAtPath:folderPath]))
	{
		return NO;
	}
	while(p = [en nextObject])
	{
		if([[p pathExtension] isEqualToString:@"dbplugin"])
		{
			[self loadDriverFromBundle:[folderPath stringByAppendingPathComponent:p]];
		}
	}
	return YES;
}

- (BOOL)loadDriverFromBundle:(NSString *)path
{
	NSBundle *bundle;
	Class theClass;
	
	if(!(bundle = [NSBundle bundleWithPath:path]))
	{
		return NO;
	}
	if(![bundle load])
	{
		return NO;
	}
	if(!(theClass = [bundle principalClass]))
	{
		[bundle unload];
		return NO;
	}
	if(!([self addDriverClass:[bundle infoDictionary] class:theClass bundlePath:path]))
	{
		[bundle unload];
		return NO;
	}
	return YES;
}


- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (id)retain
{
	return self;
}

- (unsigned int)retainCount
{
	return UINT_MAX;
}

- (void)release
{
}

- (id)autorelease
{
	return self;
}

@end
