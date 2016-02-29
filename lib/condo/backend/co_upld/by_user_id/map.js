function(doc) {
    if(doc.type === 'co_upld') {
        emit(doc.user_id, null);
    }
}
