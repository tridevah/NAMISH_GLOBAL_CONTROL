const getErpDeliveryStatus = (delivery, draft_status) => {
  if (draft_status === 'DRAFT') return 'DRAFT'
  if (!delivery) return 'UNKNOWN'
  if (delivery.lookup_status === 'EVENT_NOT_FOUND') return 'EVENT_NOT_FOUND'
  if (delivery.event_status === 'NOT_YET_PUBLISHED') return 'DRAFT'

  const erpEndpointId = '4eb4da3b-c802-4d44-98b4-9859528e6beb'
  const erp = delivery.deliveries?.find((d) => d.endpoint_id === erpEndpointId)
  
  if (!erp) return 'ERP_DELIVERY_NOT_FOUND'

  if (erp.delivery_status === 'SUCCESS') return 'Delivered'
  if (erp.delivery_status === 'DEAD') return 'Failed'
  if (erp.delivery_status === 'PENDING' || erp.delivery_status === 'CLAIMED') return 'Pending'
  return erp.delivery_status
}

console.log("TEST 1: Another endpoint succeeds, ERP fails");
const t1 = getErpDeliveryStatus({
  event_status: 'SUCCESS',
  deliveries: [
    { endpoint_id: 'some-other-id', delivery_status: 'SUCCESS' },
    { endpoint_id: '4eb4da3b-c802-4d44-98b4-9859528e6beb', delivery_status: 'DEAD' }
  ]
}, 'PUBLISHED');
console.log("-> Result:", t1);

console.log("\nTEST 2: Another endpoint succeeds, ERP absent");
const t2 = getErpDeliveryStatus({
  event_status: 'SUCCESS',
  deliveries: [
    { endpoint_id: 'some-other-id', delivery_status: 'SUCCESS' }
  ]
}, 'PUBLISHED');
console.log("-> Result:", t2);

console.log("\nTEST 3: Sequence-5 standard success");
const t3 = getErpDeliveryStatus({
  event_status: 'SUCCESS',
  deliveries: [
    { endpoint_id: '4eb4da3b-c802-4d44-98b4-9859528e6beb', delivery_status: 'SUCCESS' }
  ]
}, 'PUBLISHED');
console.log("-> Result:", t3);
