//
//  ZCAddressBook.m

//

#import "ZCAddressBook.h"


static ZCAddressBook *instance = 0;
@implementation ZCAddressBook

// 单列模式
+ (ZCAddressBook*)instance
{
    @synchronized(self) {
        if(!instance) {
            instance = [[ZCAddressBook alloc] init];
        }
    }
    return instance;
}
+(void)initialize
{
    static dispatch_once_t t;
    dispatch_once(&t, ^(void){
        CFRelease(ABPersonCreate());//
    });
}
#pragma  mark 添加联系人
// 添加联系人（联系人名称、号码、号码备注标签）
- (BOOL)addContactName:(NSString*)name phoneNum:(NSString*)num withLabel:(NSString*)label{
    // 创建一条空的联系人
    ABRecordRef record = ABPersonCreate();
    CFErrorRef error;
    // 设置联系人的名字
    ABRecordSetValue(record, kABPersonFirstNameProperty, (__bridge CFTypeRef)name, &error);
    // 添加联系人电话号码以及该号码对应的标签名
    ABMutableMultiValueRef multi = ABMultiValueCreateMutable(kABPersonPhoneProperty);
    ABMultiValueAddValueAndLabel(multi, (__bridge CFTypeRef)num, (__bridge CFTypeRef)label, NULL);
    ABRecordSetValue(record, kABPersonPhoneProperty, multi, &error);
    ABAddressBookRef addressBook = nil;
    // 如果为iOS6以上系统，需要等待用户确认是否允许访问通讯录。
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0)
    {
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        //等待同意后向下执行
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error)
                                                 {
                                                     dispatch_semaphore_signal(sema);
                                                 });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
    }
    else
    {
        addressBook = ABAddressBookCreate();
    }
    // 将新建联系人记录添加如通讯录中
    BOOL success = ABAddressBookAddRecord(addressBook, record, &error);
    if (!success)
    {
        return NO;
    }else{
        // 如果添加记录成功，保存更新到通讯录数据库中
        success = ABAddressBookSave(addressBook, &error);
        CFRelease(record);
        CFRelease(addressBook);
        return success;
    }
}
#pragma  mark 指定号码是否已经存在
- (ABHelperCheckExistResultType)existPhone:(NSString*)phoneNum
{
    ABAddressBookRef addressBook = nil;
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0)
    {
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        //等待同意后向下执行
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error)
                                                 {
                                                     dispatch_semaphore_signal(sema);
                                                 });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
    }
    else
    {
        addressBook = ABAddressBookCreate();
    }
    CFArrayRef records;
    if (addressBook)
    {
        
        // 获取通讯录中全部联系人
        records = ABAddressBookCopyArrayOfAllPeople(addressBook);
    }
    else
    {
        
#ifdef DEBUG        NSLog(@"can not connect to address book");
#endif
        return ABHelperCanNotConncetToAddressBook;
    }
    // 遍历全部联系人，检查是否存在指定号码
    for (int i=0; i<CFArrayGetCount(records); i++)
    {
        ABRecordRef record = CFArrayGetValueAtIndex(records, i);
        CFTypeRef items = ABRecordCopyValue(record, kABPersonPhoneProperty);
        CFArrayRef phoneNums = ABMultiValueCopyArrayOfAllValues(items);
        if (phoneNums)
        {
            for (int j=0; j<CFArrayGetCount(phoneNums); j++)
            {
                NSString *phone = (NSString*)CFArrayGetValueAtIndex(phoneNums, j);
                if ([phone isEqualToString:phoneNum])
                {
                    return ABHelperExistSpecificContact;
                }
            }
        }
    }
    CFRelease(addressBook);
    return ABHelperNotExistSpecificContact;
}
#pragma mark 获取通讯录内容
-(NSMutableArray*)getContacts:(NSArray *)searchKeys
{
    self.dataArray = [NSMutableArray arrayWithCapacity:0];
    //取得本地通信录名柄
    ABAddressBookRef addressBook ;
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 6.0)
    {
        addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        //等待同意后向下执行
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error)
                                                 {
                                                     dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        dispatch_release(sema);
    }
    else
    {
        addressBook = ABAddressBookCreate();
    }
    
    //取得本地所有联系人记录
    CFArrayRef results = ABAddressBookCopyArrayOfAllPeople(addressBook);
    for(int i = 0; i < CFArrayGetCount(results); i++)
    {
        NSMutableDictionary *dicInfoLocal = [NSMutableDictionary dictionaryWithCapacity:0];
        ABRecordRef person = CFArrayGetValueAtIndex(results, i);
        //姓名
        NSString * name = @"";
        //读取firstName
        NSString *firtname = (NSString*)ABRecordCopyValue(person, kABPersonFirstNameProperty);
        if(firtname != nil)
            name = [NSString stringWithFormat:@"%@%@",firtname,name];
        //读取middlename
        NSString *middlename = (NSString*)ABRecordCopyValue(person, kABPersonMiddleNameProperty);
        if(middlename != nil)
            name = [NSString stringWithFormat:@"%@%@",middlename,name];
        //读取lastname
        NSString *lastname = (NSString*)ABRecordCopyValue(person, kABPersonLastNameProperty);
        if(lastname != nil)
             name = [NSString stringWithFormat:@"%@%@",lastname,name];
       
        [dicInfoLocal setObject:name forKey:@"name"];//名字，用于排序等
        for(int i = 0;i < [searchKeys count];i++)
        {
            ABPropertyID pid = [[searchKeys objectAtIndex:i] intValue];
            NSString * key = [NSString stringWithFormat:@"%d",pid];
            id value = 0;
            if(pid == kABPersonBirthdayProperty)
            {
                value = (NSDate*)ABRecordCopyValue(person, kABPersonBirthdayProperty);
            }
            else if (pid == kABPersonKindProperty)
            {
                value = (NSNumber *)ABRecordCopyValue(person, kABPersonKindProperty);
            }
            else if (pid == kABPersonEmailProperty)
            {
                value = [self getEmails:person];
            }
            else if (pid == kABPersonAddressProperty)
            {
                value = [self getAddresses:person];
            }
            else if (pid == kABPersonDateProperty || pid == kABPersonCreationDateProperty || pid == kABPersonModificationDateProperty)
            {
                value = [self getDates:person];
            }
            else if (pid == kABPersonInstantMessageProperty)
            {
                value = [self getIMs:person];
            }
            else if (pid == kABPersonPhoneProperty)
            {
                value = [self getPhones:person];
            }
            else if (pid == kABPersonURLProperty)
            {
                value = [self getURLs:person];
            }
            else if (pid == kABPersonRelatedNamesProperty)
            {
                value = [self getRelatedNames:person];
            }
            else
            {
                value = (NSString *)ABRecordCopyValue(person, pid);
            }
            if(value)
            {
                [dicInfoLocal setObject:value forKey:key];
            }
        }//for
        
        //读取照片
        NSData *image = (NSData*)ABPersonCopyImageData(person);
        if(image)
        {
            [dicInfoLocal setObject:image forKey:@"image"];
        }
        [self.dataArray addObject:dicInfoLocal];//
    }
    CFRelease(results);//new
    CFRelease(addressBook);//new
    return self.dataArray;
}

-(NSMutableArray *)getEmails:(ABRecordRef)person
{
    //获取email多值
    NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef email = ABRecordCopyValue(person, kABPersonEmailProperty);
    int emailcount = ABMultiValueGetCount(email);
    for (int x = 0; x < emailcount; x++)
    {
        //获取email Label
        NSString* emailLabel = (NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(email, x));
        //获取email值
        NSString* emailContent = (NSString*)ABMultiValueCopyValueAtIndex(email, x);
        
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(emailLabel) dic[@"label"] = emailLabel;
        if(emailContent) dic[@"content"] = emailContent;
        [array addObject:dic];
    }
    return array;
}
-(NSMutableArray *)getAddresses:(ABRecordRef)person
{
    //读取地址多值
    NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef address = ABRecordCopyValue(person, kABPersonAddressProperty);
    int count = ABMultiValueGetCount(address);
    for(int j = 0; j < count; j++)
    {
        //获取地址Label
        NSString* addressLabel = (NSString*)ABMultiValueCopyLabelAtIndex(address, j);
        //获取該label下的地址6属性
        NSDictionary* personaddress =(NSDictionary*) ABMultiValueCopyValueAtIndex(address, j);
        
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(addressLabel) dic[@"label"] = addressLabel;
        if(personaddress) dic[@"content"] = personaddress;
        [array addObject:dic];
    }
    return array;

}

-(NSMutableArray *)getDates:(ABRecordRef)person
{
    //获取dates多值
     NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef dates = ABRecordCopyValue(person, kABPersonDateProperty);
    int datescount = ABMultiValueGetCount(dates);
    for (int y = 0; y < datescount; y++)
    {
        //获取dates Label
        NSString* datesLabel = (NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(dates, y));
        //获取dates值
        NSString* datesContent = (NSString*)ABMultiValueCopyValueAtIndex(dates, y);
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(datesLabel) dic[@"label"] = datesLabel;
        if(datesContent) dic[@"content"] = datesContent;
        [array addObject:dic];
    }
    return array;

}

-(NSMutableArray *)getIMs:(ABRecordRef)person
{
    //获取IM多值
    NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef instantMessage = ABRecordCopyValue(person, kABPersonInstantMessageProperty);
    for (int l = 1; l < ABMultiValueGetCount(instantMessage); l++)
    {
        //获取IM Label
        NSString* instantMessageLabel = (NSString*)ABMultiValueCopyLabelAtIndex(instantMessage, l);
        //获取該label下的2属性
        NSDictionary* instantMessageContent =(NSDictionary*) ABMultiValueCopyValueAtIndex(instantMessage, l);
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(instantMessageLabel) dic[@"label"] = instantMessageLabel;
        if(instantMessageContent) dic[@"content"] = instantMessageContent;
        [array addObject:dic];
    }
    return array;

}
-(NSMutableArray *)getPhones:(ABRecordRef)person
{
    //读取电话多值
    NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef phone = ABRecordCopyValue(person, kABPersonPhoneProperty);
    for (int k = 0; k<ABMultiValueGetCount(phone); k++)
    {
        //获取电话Label
        NSString * personPhoneLabel = (NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(phone, k));
        //获取該Label下的电话值
        NSString * personPhone = (NSString*)ABMultiValueCopyValueAtIndex(phone, k);
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(personPhoneLabel) dic[@"label"] = personPhoneLabel;
        if(personPhone) dic[@"content"] = personPhone;
        [array addObject:dic];
    }
    return array;
}
-(NSMutableArray *)getRelatedNames:(ABRecordRef)person
{
    NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef phone = ABRecordCopyValue(person, kABPersonRelatedNamesProperty);
    for (int k = 0; k<ABMultiValueGetCount(phone); k++)
    {
        NSString * label = (NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(phone, k));
        NSString * content = (NSString*)ABMultiValueCopyValueAtIndex(phone, k);
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(label) dic[@"label"] = label;
        if(content) dic[@"content"] = content;
        [array addObject:dic];
    }
    return array;
}
-(NSMutableArray *)getURLs:(ABRecordRef)person
{
    //获取URL多值
     NSMutableArray * array = [NSMutableArray array];
    ABMultiValueRef url = ABRecordCopyValue(person, kABPersonURLProperty);
    for (int m = 0; m < ABMultiValueGetCount(url); m++)
    {
        //获取电话Label
        NSString * urlLabel = (NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(url, m));
        //获取該Label下的电话值
        NSString * urlContent = (NSString*)ABMultiValueCopyValueAtIndex(url,m);
        NSMutableDictionary * dic = [NSMutableDictionary dictionary];
        if(urlLabel) dic[@"label"] = urlLabel;
        if(urlContent) dic[@"content"] = urlContent;
        [array addObject:dic];
    }
    return array;

}


-(NSArray*)getSortedContacts:(NSArray *)searchKeys
{
    if(!self.dataArray) [self getContacts:searchKeys];
    NSArray*array =  [self.dataArray sortedArrayUsingFunction:cmp context:NULL];
    return array;
    
}
NSInteger cmp(NSDictionary * first, NSDictionary* second, void * p)
{
    NSString * a = [first objectForKey:@"name"];
    NSString * b = [second objectForKey:@"name"];
    int res = NSOrderedAscending;
    if(a && [a length] > 0)
    {
        char ac = pinyinFirstLetter([a characterAtIndex:0]);
        res = NSOrderedDescending;
        if(b && [b length] > 0)
        {
            char bc = pinyinFirstLetter([b characterAtIndex:0]);
            //
            if(ac > bc)
            {
                res = NSOrderedDescending;//(1)
            }else
                res = NSOrderedAscending;//(-1)
        }
    }
    return res;
}

-(NSDictionary*)getSortedContactsWithKeys:(NSArray *)searchKeys
{
    NSArray * sorted = [self getSortedContacts:searchKeys];
    NSMutableDictionary * res = [NSMutableDictionary dictionary];
    for(int i = 0;i < [sorted count];i++)
    {
        NSDictionary * item = [sorted objectAtIndex:i];
        NSString * str = [item objectForKey:@"name"];
        char c = ' ';
        if([str length] > 0)
            c = pinyinFirstLetter([str characterAtIndex:0]);
        NSString * key = [NSString stringWithFormat:@"%c",c];
        NSMutableArray * array = [res objectForKey:key];
        if(!array)
        {
            array = [NSMutableArray array];
            [res setObject:array forKey:key];
        }
        [array addObject:item];
    }
    return res;
}

@end
