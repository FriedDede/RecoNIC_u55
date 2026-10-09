#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/elfnote-lto.h>
#include <linux/export-internal.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

#ifdef CONFIG_UNWINDER_ORC
#include <asm/orc_header.h>
ORC_HEADER;
#endif

BUILD_SALT;
BUILD_LTO_INFO;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0xa0be002a, "alloc_etherdev_mqs" },
	{ 0x587f22d7, "devmap_managed_key" },
	{ 0xc1514a3b, "free_irq" },
	{ 0xc31db0ce, "is_vmalloc_addr" },
	{ 0x691964ac, "__skb_pad" },
	{ 0x1e2abf24, "get_user_pages_fast" },
	{ 0xe3ec2f2b, "alloc_chrdev_region" },
	{ 0x9e7d6bd0, "__udelay" },
	{ 0x49cd25ed, "alloc_workqueue" },
	{ 0xca8743d4, "pci_msix_vec_count" },
	{ 0x3332227, "pci_enable_device" },
	{ 0xc60d0620, "__num_online_cpus" },
	{ 0x115b1577, "__napi_alloc_skb" },
	{ 0x7f02188f, "__msecs_to_jiffies" },
	{ 0xfb4f5d30, "pci_bus_max_busnr" },
	{ 0x3569adae, "pci_iomap" },
	{ 0x25a2521c, "netif_napi_add_weight" },
	{ 0x656e4a6e, "snprintf" },
	{ 0x5c4b74c7, "pci_vfs_assigned" },
	{ 0xc5b6f236, "queue_work_on" },
	{ 0x1ba59527, "__kmalloc_node" },
	{ 0xbdb56c60, "unregister_netdev" },
	{ 0x92540fbf, "finish_wait" },
	{ 0xbaa526e8, "dma_unmap_page_attrs" },
	{ 0x75646747, "class_destroy" },
	{ 0xe067206b, "__pci_register_driver" },
	{ 0xcf2a6966, "up" },
	{ 0xedc03953, "iounmap" },
	{ 0x677859bd, "pci_num_vf" },
	{ 0xaeabe9d5, "pci_request_regions" },
	{ 0x6df1aaf1, "kernel_sigaction" },
	{ 0x69acdf38, "memcpy" },
	{ 0x37a0cba, "kfree" },
	{ 0x9c2073a, "__put_devmap_managed_page_refs" },
	{ 0xdc0e4855, "timer_delete" },
	{ 0x8c26d495, "prepare_to_wait_event" },
	{ 0xb1f15f5b, "dev_kfree_skb_irq_reason" },
	{ 0xb3f7646e, "kthread_should_stop" },
	{ 0xe2964344, "__wake_up" },
	{ 0xa57a2df, "__netif_napi_del" },
	{ 0xf861aacd, "kmem_cache_create" },
	{ 0x34db050b, "_raw_spin_lock_irqsave" },
	{ 0xb19a5453, "__per_cpu_offset" },
	{ 0xf8145464, "__dynamic_dev_dbg" },
	{ 0xba8fbd64, "_raw_spin_lock" },
	{ 0x69e8d0a5, "pci_unregister_driver" },
	{ 0xcbd4898c, "fortify_panic" },
	{ 0x38537250, "netdev_err" },
	{ 0xbdfb6dbb, "__fentry__" },
	{ 0xf87c611c, "wake_up_process" },
	{ 0xa4bffd29, "dev_driver_string" },
	{ 0x32a68c03, "dev_addr_mod" },
	{ 0x1bf79915, "eth_type_trans" },
	{ 0x284faa6b, "__x86_indirect_thunk_r11" },
	{ 0x65487097, "__x86_indirect_thunk_rax" },
	{ 0x6fba437, "dma_map_page_attrs" },
	{ 0xbf57893a, "napi_complete_done" },
	{ 0x122c3a7e, "_printk" },
	{ 0x1000e51, "schedule" },
	{ 0x8ddd8aad, "schedule_timeout" },
	{ 0xf0fdf6cb, "__stack_chk_fail" },
	{ 0x296695f, "refcount_warn_saturate" },
	{ 0xb2fcb56d, "queue_delayed_work_on" },
	{ 0xe46021ca, "_raw_spin_unlock_bh" },
	{ 0x762711ac, "__napi_schedule" },
	{ 0xfe916dc6, "hex_dump_to_buffer" },
	{ 0xccbc6707, "pci_enable_msix_range" },
	{ 0xa916b694, "strnlen" },
	{ 0x618911fc, "numa_node" },
	{ 0x6383b27c, "__x86_indirect_thunk_rdx" },
	{ 0xd1485b29, "__free_pages" },
	{ 0x4c1a9a5, "kmem_cache_alloc" },
	{ 0x6079cf62, "_dev_info" },
	{ 0x167c5967, "print_hex_dump" },
	{ 0x87a21cb3, "__ubsan_handle_out_of_bounds" },
	{ 0x7cd8d75e, "page_offset_base" },
	{ 0x6b732375, "cdev_add" },
	{ 0xbcb36fe4, "hugetlb_optimize_vmemmap_key" },
	{ 0xfe487975, "init_wait_entry" },
	{ 0xfe15742c, "_dev_err" },
	{ 0x92d5838e, "request_threaded_irq" },
	{ 0x41f09736, "netif_set_real_num_tx_queues" },
	{ 0xc38c83b8, "mod_timer" },
	{ 0x3b69de06, "device_create" },
	{ 0x7d4b3ecd, "netif_set_real_num_rx_queues" },
	{ 0x6626afca, "down" },
	{ 0x6ca9b86a, "class_create" },
	{ 0x4c03a563, "random_kmalloc_seed" },
	{ 0x8c03d20c, "destroy_workqueue" },
	{ 0x4dfa8d4b, "mutex_lock" },
	{ 0x68aa2461, "kmem_cache_free" },
	{ 0xac5bfa41, "dma_alloc_attrs" },
	{ 0x6a7a92b8, "debugfs_remove" },
	{ 0x4d3cbfa8, "napi_enable" },
	{ 0x2f817980, "netif_receive_skb" },
	{ 0x5231d2f, "register_netdev" },
	{ 0x9166fada, "strncpy" },
	{ 0xbed2fe94, "free_netdev" },
	{ 0x4c9d28b0, "phys_base" },
	{ 0xde80cd09, "ioremap" },
	{ 0x2ef1b23, "kthread_stop" },
	{ 0x15ea0083, "ethtool_op_get_link" },
	{ 0xd35cce70, "_raw_spin_unlock_irqrestore" },
	{ 0x8518a4a6, "_raw_spin_trylock_bh" },
	{ 0x3ea444ae, "pci_iounmap" },
	{ 0xdaa5f566, "netif_tx_stop_all_queues" },
	{ 0xfb578fc5, "memset" },
	{ 0xc156a0bf, "__alloc_pages" },
	{ 0x7afd69b6, "pci_set_master" },
	{ 0x9166fc03, "__flush_workqueue" },
	{ 0x5b8239ca, "__x86_return_thunk" },
	{ 0xd9a5ea54, "__init_waitqueue_head" },
	{ 0x53be26d8, "kthread_bind" },
	{ 0x880af2e3, "pcie_capability_clear_and_set_word_unlocked" },
	{ 0x6b55456a, "__dynamic_netdev_dbg" },
	{ 0x15ba50a6, "jiffies" },
	{ 0xf1a358b2, "dma_set_coherent_mask" },
	{ 0x1f337bd7, "kthread_create_on_node" },
	{ 0xbca3e995, "set_page_dirty" },
	{ 0x3c3ff9fd, "sprintf" },
	{ 0x97651e6c, "vmemmap_base" },
	{ 0xdd64e639, "strscpy" },
	{ 0xa648e561, "__ubsan_handle_shift_out_of_bounds" },
	{ 0x9f3bd1c3, "dma_free_attrs" },
	{ 0x8a180849, "pcie_get_readrq" },
	{ 0x6091b333, "unregister_chrdev_region" },
	{ 0x3213f038, "mutex_unlock" },
	{ 0x9fa7184a, "cancel_delayed_work_sync" },
	{ 0xc6f46339, "init_timer_key" },
	{ 0x54800a23, "pci_release_regions" },
	{ 0xeae3dfd6, "__const_udelay" },
	{ 0x66cca4f9, "__x86_indirect_thunk_rcx" },
	{ 0x9cbc9023, "__folio_put" },
	{ 0x5b40b481, "device_destroy" },
	{ 0x2cf56265, "__dynamic_pr_debug" },
	{ 0x56470118, "__warn_printk" },
	{ 0x7fd383d9, "netif_carrier_off" },
	{ 0xffeedf6a, "delayed_work_timer_fn" },
	{ 0x4d9138cb, "pci_disable_sriov" },
	{ 0xc3690fc, "_raw_spin_lock_bh" },
	{ 0x9868babd, "netif_carrier_on" },
	{ 0x8cd868ae, "pci_disable_msix" },
	{ 0x5e209337, "pci_disable_device" },
	{ 0x4fc247bf, "pcie_set_readrq" },
	{ 0x6f584963, "dma_set_mask" },
	{ 0x41ed3709, "get_random_bytes" },
	{ 0xd0c3484c, "kmalloc_trace" },
	{ 0x26b66659, "__napi_schedule_irqoff" },
	{ 0xf8177e90, "napi_schedule_prep" },
	{ 0x54b1fac6, "__ubsan_handle_load_invalid_value" },
	{ 0x754d539c, "strlen" },
	{ 0xd8379ea4, "napi_disable" },
	{ 0x40ed958e, "dev_kfree_skb_any_reason" },
	{ 0x91eb9b4, "round_jiffies" },
	{ 0x4292a372, "debugfs_create_dir" },
	{ 0xb5b54b34, "_raw_spin_unlock" },
	{ 0xed24333b, "pci_enable_sriov" },
	{ 0xf90a1e85, "__x86_indirect_thunk_r8" },
	{ 0x858c69be, "cdev_init" },
	{ 0xeb233a45, "__kmalloc" },
	{ 0xe2c17b5d, "__SCT__might_resched" },
	{ 0x8da0819, "kmalloc_caches" },
	{ 0x4718c045, "netdev_info" },
	{ 0xc892ac3e, "cdev_del" },
	{ 0x1a0d771, "kmem_cache_destroy" },
	{ 0x2d3385d3, "system_wq" },
	{ 0x609f1c7e, "synchronize_net" },
	{ 0xe2fd41e5, "module_layout" },
};

MODULE_INFO(depends, "");

MODULE_ALIAS("pci:v000010EEd00009048sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd00009148sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd00009248sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd00009348sv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd0000903Fsv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd0000913Fsv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd0000923Fsv*sd*bc*sc*i*");
MODULE_ALIAS("pci:v000010EEd0000933Fsv*sd*bc*sc*i*");

MODULE_INFO(srcversion, "CDC0FC904E105C293F64A2F");
